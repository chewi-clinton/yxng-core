from flask import Blueprint, jsonify, request

from .gemini_client import (
    AIClientError,
    get_breakdown,
    get_roadmap_breakdown,
    get_tailored_resume,
)

bp = Blueprint("ai", __name__)


@bp.get("/health")
def health():
    return {"status": "ok"}, 200


@bp.post("/ai/breakdown")
def breakdown():
    payload = request.get_json(silent=True) or {}
    if not payload.get("title") or not payload.get("start_date"):
        return jsonify({"error": "title and start_date are required"}), 400
    try:
        tasks = get_breakdown(payload)
    except AIClientError as exc:
        return jsonify({"error": str(exc)}), 502
    return jsonify({"tasks": tasks}), 200


@bp.post("/ai/roadmap")
def roadmap():
    payload = request.get_json(silent=True) or {}
    if not payload.get("topic"):
        return jsonify({"error": "topic is required"}), 400
    try:
        milestones = get_roadmap_breakdown(payload)
    except AIClientError as exc:
        return jsonify({"error": str(exc)}), 502
    return jsonify({"milestones": milestones}), 200


@bp.post("/ai/tailor-cv")
def tailor_cv():
    payload = request.get_json(silent=True) or {}
    required = ["resume_text", "job_title", "job_description"]
    if not all(payload.get(f) for f in required):
        return (
            jsonify({"error": "resume_text, job_title, and job_description are required"}),
            400,
        )
    try:
        tailored = get_tailored_resume(payload)
    except AIClientError as exc:
        return jsonify({"error": str(exc)}), 502
    return jsonify({"tailored_resume": tailored}), 200
