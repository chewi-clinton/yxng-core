from datetime import timedelta
from unittest.mock import patch

from django.core import signing
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import User

from .models import GoogleCalendarConnection, SyncedEvent
from .services.google_client import GoogleCalendarError
from .services.sync import sync_task
from .views import STATE_SALT


class FakeTask:
    """Avoids a real project/schedule dependency for sync-service unit tests."""

    def __init__(self, owner, scheduled_start=None, scheduled_end=None):
        self.id = 1
        self.title = "Ship it"
        self.description = ""
        self.scheduled_start = scheduled_start
        self.scheduled_end = scheduled_end
        self.project = type("P", (), {"owner": owner, "title": "Test project"})()


class ConnectStatusTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="clinton", password="pass12345!")
        self.client.force_authenticate(user=self.user)

    def test_connect_returns_google_auth_url(self):
        response = self.client.get("/api/v1/calendar/connect/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("accounts.google.com", response.data["auth_url"])

    def test_status_when_not_connected(self):
        response = self.client.get("/api/v1/calendar/status/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data["connected"])

    def test_status_when_connected(self):
        GoogleCalendarConnection.objects.create(owner=self.user, refresh_token="rt")
        response = self.client.get("/api/v1/calendar/status/")
        self.assertTrue(response.data["connected"])

    def test_disconnect_removes_connection(self):
        GoogleCalendarConnection.objects.create(owner=self.user, refresh_token="rt")
        response = self.client.delete("/api/v1/calendar/status/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(GoogleCalendarConnection.objects.filter(owner=self.user).exists())

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        response = self.client.get("/api/v1/calendar/status/")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class CallbackTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="clinton", password="pass12345!")

    def _state(self):
        return signing.dumps({"user_id": self.user.id}, salt=STATE_SALT)

    @patch(
        "apps.calendar_sync.views.exchange_code_for_tokens",
        return_value={"access_token": "at", "refresh_token": "rt", "expires_in": 3600},
    )
    def test_callback_stores_connection(self, mock_exchange):
        response = self.client.get(
            "/api/v1/calendar/callback/", {"code": "abc", "state": self._state()}
        )
        self.assertEqual(response.status_code, 200)
        connection = GoogleCalendarConnection.objects.get(owner=self.user)
        self.assertEqual(connection.refresh_token, "rt")

    def test_callback_rejects_bad_state(self):
        response = self.client.get(
            "/api/v1/calendar/callback/", {"code": "abc", "state": "not-a-real-state"}
        )
        self.assertEqual(response.status_code, 400)

    def test_callback_reports_google_error(self):
        response = self.client.get("/api/v1/calendar/callback/", {"error": "access_denied"})
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"cancelled", response.content)

    @patch(
        "apps.calendar_sync.views.exchange_code_for_tokens",
        side_effect=GoogleCalendarError("boom"),
    )
    def test_callback_reports_exchange_failure(self, mock_exchange):
        response = self.client.get(
            "/api/v1/calendar/callback/", {"code": "abc", "state": self._state()}
        )
        self.assertEqual(response.status_code, 502)


class SyncServiceTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="clinton", password="pass12345!")

    def test_sync_task_noop_when_not_connected(self):
        task = FakeTask(
            self.user, timezone.now(), timezone.now() + timedelta(hours=1)
        )
        # Should not raise even though there's no GoogleCalendarConnection.
        sync_task(task)
        self.assertFalse(SyncedEvent.objects.exists())

    def test_sync_task_noop_when_unscheduled(self):
        GoogleCalendarConnection.objects.create(owner=self.user, refresh_token="rt")
        task = FakeTask(self.user)
        sync_task(task)
        self.assertFalse(SyncedEvent.objects.exists())

    @patch(
        "apps.calendar_sync.services.sync.upsert_event",
        return_value={"id": "gcal-event-1"},
    )
    def test_sync_task_creates_synced_event_when_connected(self, mock_upsert):
        GoogleCalendarConnection.objects.create(
            owner=self.user,
            refresh_token="rt",
            access_token="at",
            token_expiry=timezone.now() + timedelta(hours=1),
        )
        task = FakeTask(
            self.user, timezone.now(), timezone.now() + timedelta(hours=1)
        )
        sync_task(task)
        mock_upsert.assert_called_once()
        synced = SyncedEvent.objects.get(owner=self.user, source_type="task", source_id=1)
        self.assertEqual(synced.google_event_id, "gcal-event-1")

    @patch(
        "apps.calendar_sync.services.sync.upsert_event",
        side_effect=GoogleCalendarError("boom"),
    )
    def test_sync_task_swallows_calendar_api_errors(self, mock_upsert):
        GoogleCalendarConnection.objects.create(
            owner=self.user,
            refresh_token="rt",
            access_token="at",
            token_expiry=timezone.now() + timedelta(hours=1),
        )
        task = FakeTask(
            self.user, timezone.now(), timezone.now() + timedelta(hours=1)
        )
        # Should not raise despite the Calendar API failing.
        sync_task(task)
