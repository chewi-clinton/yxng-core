from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import User

from .models import Project, Resource, Task
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


class ProjectResourceTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(username="owner", password="pass12345!")
        self.other = User.objects.create_user(username="other", password="pass12345!")
        self.project = Project.objects.create(
            owner=self.owner, title="Owner's project", start_date="2026-07-20"
        )
        self.list_url = f"/api/v1/projects/{self.project.id}/resources/"

    def test_owner_can_add_link_resource(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.post(
            self.list_url,
            {"kind": "link", "title": "Docs", "url": "https://example.com/docs"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        resource = Resource.objects.get(project=self.project)
        self.assertEqual(resource.kind, "link")
        self.assertEqual(resource.url, "https://example.com/docs")

    def test_link_resource_requires_url(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.post(
            self.list_url, {"kind": "link", "title": "Docs"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_owner_can_add_file_resource(self):
        self.client.force_authenticate(user=self.owner)
        upload = SimpleUploadedFile("diagram.png", b"fake-png-bytes", content_type="image/png")
        response = self.client.post(
            self.list_url, {"kind": "file", "title": "Diagram", "file": upload}, format="multipart"
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        resource = Resource.objects.get(project=self.project)
        self.assertEqual(resource.kind, "file")
        self.assertEqual(resource.filename, "diagram.png")
        self.assertEqual(bytes(resource.file), b"fake-png-bytes")

    def test_download_returns_file_bytes(self):
        resource = Resource.objects.create(
            project=self.project,
            kind="file",
            title="Diagram",
            file=b"fake-png-bytes",
            filename="diagram.png",
            content_type="image/png",
        )
        self.client.force_authenticate(user=self.owner)
        response = self.client.get(f"/api/v1/projects/resources/{resource.id}/download/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.content, b"fake-png-bytes")
        self.assertEqual(response["Content-Type"], "image/png")

    def test_other_user_sees_no_resources_and_cannot_delete(self):
        resource = Resource.objects.create(
            project=self.project, kind="link", title="Docs", url="https://example.com"
        )
        self.client.force_authenticate(user=self.other)
        # Same scoping pattern as the existing task list: another user's
        # project resource list comes back empty (200), not 404.
        list_response = self.client.get(self.list_url)
        self.assertEqual(list_response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(list_response.data), 0)
        self.assertEqual(
            self.client.delete(f"/api/v1/projects/resources/{resource.id}/").status_code,
            status.HTTP_404_NOT_FOUND,
        )
        self.assertTrue(Resource.objects.filter(id=resource.id).exists())

    def test_other_user_cannot_create_resource_on_someone_elses_project(self):
        self.client.force_authenticate(user=self.other)
        response = self.client.post(
            self.list_url,
            {"kind": "link", "title": "Docs", "url": "https://example.com"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_owner_can_delete_resource(self):
        resource = Resource.objects.create(
            project=self.project, kind="link", title="Docs", url="https://example.com"
        )
        self.client.force_authenticate(user=self.owner)
        response = self.client.delete(f"/api/v1/projects/resources/{resource.id}/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Resource.objects.filter(id=resource.id).exists())

    def test_requires_authentication(self):
        response = self.client.get(self.list_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
