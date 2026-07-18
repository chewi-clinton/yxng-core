from typing import List

from google import genai
from google.genai import types
from pydantic import BaseModel

from .config import GEMINI_API_KEY, GEMINI_MODEL

client = genai.Client(api_key=GEMINI_API_KEY)


class TaskItem(BaseModel):
    title: str
    description: str
    estimated_duration_minutes: int
    order: int


class TaskBreakdown(BaseModel):
    tasks: List[TaskItem]


class AIClientError(Exception):
    pass


PROMPT_TEMPLATE = """Break the following software project into a sequence of concrete, \
independently completable engineering tasks, ordered by dependency (earliest first).

Title: {title}
Description: {description}
Tech stack: {tech_stack}

Estimate a realistic duration in minutes for one focused developer per task."""


def get_breakdown(payload: dict) -> list[dict]:
    prompt = PROMPT_TEMPLATE.format(
        title=payload["title"],
        description=payload.get("description", ""),
        tech_stack=", ".join(payload.get("tech_stack", [])) or "unspecified",
    )
    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=TaskBreakdown,
            ),
        )
    except Exception as exc:
        raise AIClientError(f"Gemini API error: {exc}") from exc

    parsed: TaskBreakdown = response.parsed
    if not parsed or not parsed.tasks:
        raise AIClientError("Gemini returned an empty or malformed task list")
    return [t.model_dump() for t in parsed.tasks]
