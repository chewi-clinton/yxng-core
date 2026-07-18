from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import User

from .models import LinkedPlatform


class LinkedPlatformTests(APITestCase):
    url = "/api/v1/payments/"

    def setUp(self):
        self.owner = User.objects.create_user(username="owner", password="pass12345!")
        self.other = User.objects.create_user(username="other", password="pass12345!")
        self.client.force_authenticate(user=self.owner)

    def test_create_linked_platform(self):
        response = self.client.post(
            self.url,
            {
                "name": "Netflix",
                "card_label": "Visa •••• 4242",
                "amount": "15.99",
                "renews_on": "2026-08-01",
                "source": "extension",
                "source_url": "https://netflix.com/account",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        platform = LinkedPlatform.objects.get(name="Netflix")
        self.assertEqual(platform.owner, self.owner)
        self.assertEqual(str(platform.amount), "15.99")
        self.assertEqual(platform.source, "extension")

    def test_list_only_returns_own_platforms(self):
        LinkedPlatform.objects.create(
            owner=self.owner, name="Mine", amount="5.00", renews_on="2026-08-01"
        )
        LinkedPlatform.objects.create(
            owner=self.other, name="Theirs", amount="9.00", renews_on="2026-08-01"
        )
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["name"], "Mine")

    def test_delete_requires_ownership(self):
        theirs = LinkedPlatform.objects.create(
            owner=self.other, name="Theirs", amount="9.00", renews_on="2026-08-01"
        )
        response = self.client.delete(f"{self.url}{theirs.id}/")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertTrue(LinkedPlatform.objects.filter(id=theirs.id).exists())

    def test_owner_can_delete_own_platform(self):
        mine = LinkedPlatform.objects.create(
            owner=self.owner, name="Mine", amount="5.00", renews_on="2026-08-01"
        )
        response = self.client.delete(f"{self.url}{mine.id}/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(LinkedPlatform.objects.filter(id=mine.id).exists())

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
