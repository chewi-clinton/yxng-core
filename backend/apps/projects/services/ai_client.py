import requests
from django.conf import settings


class AIServiceError(Exception):
    """Raised on any failure reaching or parsing the AI worker's response."""


def get_task_breakdown(project) -> list[dict]:
    payload = {
        "title": project.title,
        "description": project.description,
        "tech_stack": project.tech_stack,
        "start_date": project.start_date.isoformat(),
    }
    try:
        resp = requests.post(
            f"{settings.AI_SERVICE_URL}/ai/breakdown",
            json=payload,
            timeout=(5, 60),  # (connect, read) seconds
        )
    except requests.exceptions.Timeout as exc:
        raise AIServiceError("AI service timed out") from exc
    except requests.exceptions.ConnectionError as exc:
        raise AIServiceError("AI service is unreachable") from exc

    if resp.status_code != 200:
        raise AIServiceError(f"AI service returned {resp.status_code}: {resp.text[:300]}")

    tasks = resp.json().get("tasks")
    if not isinstance(tasks, list) or not tasks:
        raise AIServiceError("AI service returned an empty or malformed task list")
    return tasks
