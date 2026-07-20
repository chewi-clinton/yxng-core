import logging
from datetime import timedelta

from django.utils import timezone

from ..models import GoogleCalendarConnection, SyncedEvent
from .google_client import GoogleCalendarError, refresh_access_token, upsert_event

logger = logging.getLogger(__name__)


def _get_access_token(connection: GoogleCalendarConnection) -> str | None:
    if connection.token_expiry and connection.token_expiry > timezone.now() + timedelta(
        minutes=2
    ):
        return connection.access_token
    try:
        tokens = refresh_access_token(connection.refresh_token)
    except GoogleCalendarError:
        logger.warning(
            "Failed to refresh Google Calendar token for user %s", connection.owner_id
        )
        return None
    connection.access_token = tokens["access_token"]
    connection.token_expiry = timezone.now() + timedelta(
        seconds=tokens.get("expires_in", 3600)
    )
    connection.save(update_fields=["access_token", "token_expiry"])
    return connection.access_token


def _upsert(owner, source_type: str, source_id: int, event_body: dict) -> None:
    """Best-effort: silently no-ops if the user isn't connected, and swallows
    any Calendar API failure rather than breaking the task/roadmap request
    that triggered it — calendar sync is a side effect, not a hard
    dependency of creating a project or roadmap."""
    try:
        connection = owner.google_calendar
    except GoogleCalendarConnection.DoesNotExist:
        return

    access_token = _get_access_token(connection)
    if not access_token:
        return

    synced, _ = SyncedEvent.objects.get_or_create(
        owner=owner,
        source_type=source_type,
        source_id=source_id,
        defaults={"google_event_id": ""},
    )
    try:
        result = upsert_event(
            access_token, connection.calendar_id, synced.google_event_id or None, event_body
        )
    except GoogleCalendarError:
        logger.warning(
            "Calendar sync failed for %s %s (user %s)", source_type, source_id, owner.id
        )
        return

    if result.get("id") and result["id"] != synced.google_event_id:
        synced.google_event_id = result["id"]
        synced.save(update_fields=["google_event_id"])


def sync_task(task) -> None:
    if not task.scheduled_start or not task.scheduled_end:
        return
    _upsert(
        task.project.owner,
        "task",
        task.id,
        {
            "summary": task.title,
            "description": task.description or f"From project: {task.project.title}",
            "start": {"dateTime": task.scheduled_start.isoformat()},
            "end": {"dateTime": task.scheduled_end.isoformat()},
        },
    )


def sync_milestone(milestone) -> None:
    if not milestone.target_date:
        return
    start = milestone.target_date.isoformat()
    end = (milestone.target_date + timedelta(days=1)).isoformat()
    _upsert(
        milestone.roadmap.owner,
        "milestone",
        milestone.id,
        {
            "summary": f"{milestone.roadmap.title}: {milestone.title}",
            "description": milestone.description,
            "start": {"date": start},
            "end": {"date": end},
        },
    )
