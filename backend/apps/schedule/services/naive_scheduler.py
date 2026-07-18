from datetime import datetime, time, timedelta

from django.utils import timezone

WORK_DAY_START = time(9, 0)
WORK_DAY_END = time(17, 0)


def _combine(date, t):
    """datetime.combine + make_aware — Django's USE_TZ=True expects every
    stored datetime to carry a timezone; plain datetime.combine produces a
    naive one, which Django will accept but warn about, silently trusting
    the process's local time rather than the project's TIME_ZONE."""
    return timezone.make_aware(datetime.combine(date, t))


def schedule_tasks(tasks: list[dict], start_date) -> list[tuple[datetime, datetime]]:
    """Naive first-fit: pack tasks back-to-back into 9-5 weekday slots starting
    at start_date. Ignores other projects and existing bookings entirely —
    Phase 2 replaces this with a calendar-aware engine that respects
    Project.consider_other_projects and a DailyRoutine model."""
    cursor = _combine(start_date, WORK_DAY_START)
    slots = []
    for task in tasks:
        duration = timedelta(minutes=task["estimated_duration_minutes"])
        while cursor.weekday() >= 5:
            cursor = _combine(cursor.date() + timedelta(days=1), WORK_DAY_START)
        day_end = _combine(cursor.date(), WORK_DAY_END)
        if cursor + duration > day_end:
            cursor = _combine(cursor.date() + timedelta(days=1), WORK_DAY_START)
            while cursor.weekday() >= 5:
                cursor = _combine(cursor.date() + timedelta(days=1), WORK_DAY_START)
        slots.append((cursor, cursor + duration))
        cursor += duration
    return slots
