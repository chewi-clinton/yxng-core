from unittest.mock import patch

from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import User

from .models import Milestone, Roadmap
from .services.ai_client import AIServiceError

FAKE_BREAKDOWN = [
    {"title": "Learn the fundamentals", "description": ""},
    {"title": "Build a small practice project", "description": ""},
]


class RoadmapCreateTests(APITestCase):
    url = "/api/v1/skills/"

    def setUp(self):
        self.user = User.objects.create_user(username="clinton", password="pass12345!")
        self.client.force_authenticate(user=self.user)

    @patch("apps.skills.views.get_roadmap_breakdown", return_value=FAKE_BREAKDOWN)
    def test_create_roadmap_generates_milestones(self, mock_breakdown):
        response = self.client.post(
            self.url,
            {"title": "GraphQL", "target_date": "2026-09-01"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        mock_breakdown.assert_called_once()
        roadmap = Roadmap.objects.get(title="GraphQL")
        self.assertEqual(roadmap.owner, self.user)
        self.assertEqual(roadmap.milestones.count(), 2)

    @patch(
        "apps.skills.views.get_roadmap_breakdown",
        side_effect=AIServiceError("boom"),
    )
    def test_ai_failure_rolls_back_and_returns_502(self, mock_breakdown):
        response = self.client.post(
            self.url, {"title": "Doomed roadmap"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_502_BAD_GATEWAY)
        self.assertFalse(Roadmap.objects.filter(title="Doomed roadmap").exists())

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        response = self.client.post(self.url, {"title": "X"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class RoadmapAccessTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(username="owner", password="pass12345!")
        self.other = User.objects.create_user(username="other", password="pass12345!")
        self.roadmap = Roadmap.objects.create(owner=self.owner, title="Owner's roadmap")
        self.milestone = Milestone.objects.create(
            roadmap=self.roadmap, title="A milestone", order=0
        )

    def test_list_only_returns_own_roadmaps(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.get("/api/v1/skills/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

        self.client.force_authenticate(user=self.other)
        response = self.client.get("/api/v1/skills/")
        self.assertEqual(len(response.data), 0)

    def test_other_user_cannot_retrieve_or_delete(self):
        self.client.force_authenticate(user=self.other)
        detail_url = f"/api/v1/skills/{self.roadmap.id}/"
        self.assertEqual(
            self.client.get(detail_url).status_code, status.HTTP_404_NOT_FOUND
        )
        self.assertEqual(
            self.client.delete(detail_url).status_code, status.HTTP_404_NOT_FOUND
        )
        self.assertTrue(Roadmap.objects.filter(id=self.roadmap.id).exists())

    def test_owner_can_delete_own_roadmap(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.delete(f"/api/v1/skills/{self.roadmap.id}/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Roadmap.objects.filter(id=self.roadmap.id).exists())

    def test_owner_can_update_milestone_status(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.patch(
            f"/api/v1/skills/milestones/{self.milestone.id}/",
            {"status": "done"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.milestone.refresh_from_db()
        self.assertEqual(self.milestone.status, "done")
