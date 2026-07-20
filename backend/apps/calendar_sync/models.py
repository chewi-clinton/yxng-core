from django.conf import settings
from django.db import models


class GoogleCalendarConnection(models.Model):
    owner = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="google_calendar"
    )
    refresh_token = models.TextField()
    access_token = models.TextField(blank=True)
    token_expiry = models.DateTimeField(null=True, blank=True)
    calendar_id = models.CharField(max_length=255, default="primary")
    connected_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "google_calendar_connections"

    def __str__(self):
        return f"{self.owner_id}: connected {self.connected_at}"


class SyncedEvent(models.Model):
    """Maps a task/milestone to the Google Calendar event created for it, so
    re-syncing updates the existing event instead of creating duplicates."""

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="synced_calendar_events",
    )
    source_type = models.CharField(max_length=20)
    source_id = models.PositiveIntegerField()
    google_event_id = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "synced_calendar_events"
        unique_together = [("owner", "source_type", "source_id")]

    def __str__(self):
        return f"{self.owner_id}: {self.source_type}:{self.source_id}"
