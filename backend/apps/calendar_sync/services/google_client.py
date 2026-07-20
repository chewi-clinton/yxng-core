from urllib.parse import urlencode

import requests
from django.conf import settings

TOKEN_URL = "https://oauth2.googleapis.com/token"
AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
CALENDAR_EVENTS_URL = "https://www.googleapis.com/calendar/v3/calendars/{calendar_id}/events"

SCOPE = "https://www.googleapis.com/auth/calendar.events"


class GoogleCalendarError(Exception):
    pass


def build_auth_url(state: str) -> str:
    params = {
        "client_id": settings.GOOGLE_CLIENT_ID,
        "redirect_uri": settings.GOOGLE_REDIRECT_URI,
        "response_type": "code",
        "scope": SCOPE,
        # offline + consent forces a refresh_token on every grant, not just
        # the first — without this a reconnect after revoking access would
        # silently fail to get one.
        "access_type": "offline",
        "prompt": "consent",
        "state": state,
    }
    return f"{AUTH_URL}?{urlencode(params)}"


def exchange_code_for_tokens(code: str) -> dict:
    resp = requests.post(
        TOKEN_URL,
        data={
            "code": code,
            "client_id": settings.GOOGLE_CLIENT_ID,
            "client_secret": settings.GOOGLE_CLIENT_SECRET,
            "redirect_uri": settings.GOOGLE_REDIRECT_URI,
            "grant_type": "authorization_code",
        },
        timeout=15,
    )
    if resp.status_code != 200:
        raise GoogleCalendarError(f"Token exchange failed: {resp.text[:300]}")
    return resp.json()


def refresh_access_token(refresh_token: str) -> dict:
    resp = requests.post(
        TOKEN_URL,
        data={
            "refresh_token": refresh_token,
            "client_id": settings.GOOGLE_CLIENT_ID,
            "client_secret": settings.GOOGLE_CLIENT_SECRET,
            "grant_type": "refresh_token",
        },
        timeout=15,
    )
    if resp.status_code != 200:
        raise GoogleCalendarError(f"Token refresh failed: {resp.text[:300]}")
    return resp.json()


def upsert_event(
    access_token: str, calendar_id: str, event_id: str | None, event_body: dict
) -> dict:
    headers = {"Authorization": f"Bearer {access_token}"}
    base_url = CALENDAR_EVENTS_URL.format(calendar_id=calendar_id)
    if event_id:
        resp = requests.patch(f"{base_url}/{event_id}", json=event_body, headers=headers, timeout=15)
    else:
        resp = requests.post(base_url, json=event_body, headers=headers, timeout=15)
    if resp.status_code not in (200, 201):
        raise GoogleCalendarError(f"Calendar API error {resp.status_code}: {resp.text[:300]}")
    return resp.json()
