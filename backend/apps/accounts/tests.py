from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import User


class RegisterTests(APITestCase):
    url = "/api/v1/auth/register/"

    def test_register_creates_user_and_returns_token(self):
        response = self.client.post(
            self.url,
            {"username": "clinton", "email": "", "password": "StrongPass123!"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["username"], "clinton")
        self.assertTrue(User.objects.filter(username="clinton").exists())
        user = User.objects.get(username="clinton")
        self.assertEqual(Token.objects.get(user=user).key, response.data["token"])

    def test_register_rejects_duplicate_username(self):
        User.objects.create_user(username="clinton", password="StrongPass123!")
        response = self.client.post(
            self.url,
            {"username": "clinton", "password": "AnotherPass123!"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_register_rejects_weak_password(self):
        response = self.client.post(
            self.url,
            {"username": "newuser", "password": "123"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class LoginTests(APITestCase):
    url = "/api/v1/auth/login/"

    def setUp(self):
        self.user = User.objects.create_user(username="clinton", password="StrongPass123!")

    def test_login_with_correct_credentials_returns_token(self):
        response = self.client.post(
            self.url,
            {"username": "clinton", "password": "StrongPass123!"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["token"], Token.objects.get(user=self.user).key)

    def test_login_with_wrong_password_fails(self):
        response = self.client.post(
            self.url,
            {"username": "clinton", "password": "wrong"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
