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


class MilestoneItem(BaseModel):
    title: str
    description: str


class RoadmapBreakdown(BaseModel):
    milestones: List[MilestoneItem]


class TailoredResume(BaseModel):
    tailored_resume: str


class AIClientError(Exception):
    pass


PROMPT_TEMPLATE = """Break the following software project into a sequence of concrete, \
independently completable engineering tasks, ordered by dependency (earliest first).

Title: {title}
Description: {description}
Tech stack: {tech_stack}

Estimate a realistic duration in minutes for one focused developer per task."""

ROADMAP_PROMPT_TEMPLATE = """Create a learning roadmap for someone who wants to learn \
"{topic}", going from their current level to a solid working proficiency.

{pacing}

Break it into an ordered sequence of concrete milestones (earliest/most foundational \
first). Each milestone should be a specific, achievable chunk of learning or practice \
(e.g. a concept to master, a small project to build, a skill to practice) — not vague \
advice. Aim for between 5 and 10 milestones depending on the scope of the topic."""

TAILOR_CV_PROMPT_TEMPLATE = """You are an expert resume writer. Rewrite and tailor the \
following resume to fit the job below as closely and honestly as possible: reorder and \
rephrase the candidate's existing experience to foreground what's relevant, mirror \
language from the job description where it's truthfully applicable, and tighten the \
professional summary to speak directly to this role.

Do not invent experience, skills, employers, dates, or qualifications that aren't \
already present in the original resume. If the resume is a poor fit for the role, \
tailor it as best as honestly possible rather than fabricating a better fit.

Job title: {job_title}
Company: {job_org}
Job description / requirements:
{job_description}

Original resume:
{resume_text}

Return the complete tailored resume as plain text, preserving the original's overall \
section structure (e.g. Summary, Skills, Experience, Education) where present."""


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


def get_roadmap_breakdown(payload: dict) -> list[dict]:
    target_date = payload.get("target_date")
    pacing = (
        f"They're aiming to reach proficiency by {target_date}, so pace the milestones "
        "to be realistically achievable by that date."
        if target_date
        else "No specific deadline — order milestones by learning dependency."
    )
    prompt = ROADMAP_PROMPT_TEMPLATE.format(topic=payload["topic"], pacing=pacing)
    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=RoadmapBreakdown,
            ),
        )
    except Exception as exc:
        raise AIClientError(f"Gemini API error: {exc}") from exc

    parsed: RoadmapBreakdown = response.parsed
    if not parsed or not parsed.milestones:
        raise AIClientError("Gemini returned an empty or malformed milestone list")
    return [m.model_dump() for m in parsed.milestones]


def get_tailored_resume(payload: dict) -> str:
    prompt = TAILOR_CV_PROMPT_TEMPLATE.format(
        job_title=payload["job_title"],
        job_org=payload.get("job_org") or "unspecified",
        job_description=payload["job_description"],
        resume_text=payload["resume_text"],
    )
    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=TailoredResume,
            ),
        )
    except Exception as exc:
        raise AIClientError(f"Gemini API error: {exc}") from exc

    parsed: TailoredResume = response.parsed
    if not parsed or not parsed.tailored_resume:
        raise AIClientError("Gemini returned an empty tailored resume")
    return parsed.tailored_resume
