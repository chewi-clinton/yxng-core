from flask import Blueprint, jsonify, request

from .gemini_client import AIClientError, get_breakdown

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
