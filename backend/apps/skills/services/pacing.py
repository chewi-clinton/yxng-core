from datetime import date, timedelta


def pace_milestones(count: int, target_date: date | None) -> list[date | None]:
    """Assign each milestone a real calendar date, evenly spaced between today
    and the roadmap's target date. Gemini orders milestones by dependency but
    has no notion of the user's actual calendar, so pacing is computed here —
    same division of responsibility as the project task scheduler."""
    if count == 0:
        return []
    if target_date is None:
        return [None] * count

    today = date.today()
    total_days = (target_date - today).days
    if total_days <= 0:
        return [target_date] * count

    step = total_days / count
    return [today + timedelta(days=round(step * (i + 1))) for i in range(count)]
