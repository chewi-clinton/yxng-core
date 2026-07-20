import requests
from django.conf import settings


class AIServiceError(Exception):
    """Raised on any failure reaching or parsing the AI worker's response."""


def get_tailored_resume(
    resume_text: str, job_title: str, job_org: str, job_description: str
) -> str:
    payload = {
        "resume_text": resume_text,
        "job_title": job_title,
        "job_org": job_org,
        "job_description": job_description,
    }
    try:
        resp = requests.post(
            f"{settings.AI_SERVICE_URL}/ai/tailor-cv",
            json=payload,
            timeout=(5, 60),
        )
    except requests.exceptions.Timeout as exc:
        raise AIServiceError("AI service timed out") from exc
    except requests.exceptions.ConnectionError as exc:
        raise AIServiceError("AI service is unreachable") from exc

    if resp.status_code != 200:
        raise AIServiceError(f"AI service returned {resp.status_code}: {resp.text[:300]}")

    tailored = resp.json().get("tailored_resume")
    if not tailored:
        raise AIServiceError("AI service returned an empty tailored resume")
    return tailored
