from unittest.mock import patch

from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import User

from .models import Project, Task
from .services.ai_client import AIServiceError

FAKE_BREAKDOWN = [
    {
        "title": "Scope the work",
        "description": "",
        "estimated_duration_minutes": 30,
        "order": 0,
    },
    {
        "title": "Build it",
        "description": "",
        "estimated_duration_minutes": 120,
        "order": 1,
    },
]


class ProjectCreateTests(APITestCase):
    url = "/api/v1/projects/"

    def setUp(self):
        self.user = User.objects.create_user(username="clinton", password="pass12345!")
        self.client.force_authenticate(user=self.user)

    @patch("apps.projects.views.get_task_breakdown", return_value=FAKE_BREAKDOWN)
    def test_create_project_breaks_down_and_schedules_tasks(self, mock_breakdown):
        response = self.client.post(
            self.url,
            {
                "title": "Build a bot",
                "tech_stack": ["Python"],
                "start_date": "2026-07-20",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        mock_breakdown.assert_called_once()
        project = Project.objects.get(title="Build a bot")
        self.assertEqual(project.owner, self.user)
        self.assertEqual(project.tasks.count(), 2)
        first_task = project.tasks.order_by("order").first()
        self.assertIsNotNone(first_task.scheduled_start)
        self.assertIsNotNone(first_task.scheduled_end)

    @patch("apps.projects.views.get_task_breakdown", side_effect=AIServiceError("boom"))
    def test_ai_failure_rolls_back_and_returns_502(self, mock_breakdown):
        response = self.client.post(
            self.url,
            {"title": "Doomed project", "start_date": "2026-07-20"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_502_BAD_GATEWAY)
        self.assertFalse(Project.objects.filter(title="Doomed project").exists())

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        response = self.client.post(
            self.url, {"title": "X", "start_date": "2026-07-20"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class ProjectAccessTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(username="owner", password="pass12345!")
        self.other = User.objects.create_user(username="other", password="pass12345!")
        self.project = Project.objects.create(
            owner=self.owner, title="Owner's project", start_date="2026-07-20"
        )
        self.task = Task.objects.create(
            project=self.project, title="A task", estimated_duration=30, order=0
        )

    def test_list_only_returns_own_projects(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.get("/api/v1/projects/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

        self.client.force_authenticate(user=self.other)
        response = self.client.get("/api/v1/projects/")
        self.assertEqual(len(response.data), 0)

    def test_other_user_cannot_retrieve_or_delete(self):
        self.client.force_authenticate(user=self.other)
        detail_url = f"/api/v1/projects/{self.project.id}/"
        self.assertEqual(
            self.client.get(detail_url).status_code, status.HTTP_404_NOT_FOUND
        )
        self.assertEqual(
            self.client.delete(detail_url).status_code, status.HTTP_404_NOT_FOUND
        )
        self.assertTrue(Project.objects.filter(id=self.project.id).exists())

    def test_owner_can_delete_own_project(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.delete(f"/api/v1/projects/{self.project.id}/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Project.objects.filter(id=self.project.id).exists())

    def test_owner_can_update_task_status(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.patch(
            f"/api/v1/projects/tasks/{self.task.id}/",
            {"status": "done"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.task.refresh_from_db()
        self.assertEqual(self.task.status, "done")
