import requests
from django.conf import settings


class AIServiceError(Exception):
    """Raised on any failure reaching or parsing the AI worker's response."""


def get_roadmap_breakdown(title: str, target_date) -> list[dict]:
    payload = {
        "topic": title,
        "target_date": target_date.isoformat() if target_date else None,
    }
    try:
        resp = requests.post(
            f"{settings.AI_SERVICE_URL}/ai/roadmap",
            json=payload,
            timeout=(5, 60),
        )
    except requests.exceptions.Timeout as exc:
        raise AIServiceError("AI service timed out") from exc
    except requests.exceptions.ConnectionError as exc:
        raise AIServiceError("AI service is unreachable") from exc

    if resp.status_code != 200:
        raise AIServiceError(f"AI service returned {resp.status_code}: {resp.text[:300]}")

    milestones = resp.json().get("milestones")
    if not isinstance(milestones, list) or not milestones:
        raise AIServiceError("AI service returned an empty or malformed milestone list")
    return milestones
