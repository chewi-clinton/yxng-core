from datetime import timedelta

from django.core import signing
from django.http import HttpResponse
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import GoogleCalendarConnection
from .services.google_client import (
    GoogleCalendarError,
    build_auth_url,
    exchange_code_for_tokens,
)

STATE_SALT = "calendar-oauth-state"


class ConnectView(APIView):
    def get(self, request):
        state = signing.dumps({"user_id": request.user.id}, salt=STATE_SALT)
        return Response({"auth_url": build_auth_url(state)})


class StatusView(APIView):
    def get(self, request):
        try:
            connection = request.user.google_calendar
        except GoogleCalendarConnection.DoesNotExist:
            return Response({"connected": False})
        return Response({"connected": True, "connected_at": connection.connected_at})

    def delete(self, request):
        GoogleCalendarConnection.objects.filter(owner=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


_HTML = """<!doctype html><html><body style="font-family: -apple-system, sans-serif;
text-align: center; padding: 60px 20px; color: #1a1a1a;">{body}</body></html>"""


class CallbackView(APIView):
    """Hit directly by Google's redirect in the user's browser, not by the
    mobile app — there's no DRF auth token here, so the Django user is
    recovered from the signed `state` param instead."""

    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        error = request.GET.get("error")
        if error:
            return HttpResponse(
                _HTML.format(body=f"<h2>Connection cancelled</h2><p>{error}</p>"),
                content_type="text/html",
            )

        code = request.GET.get("code")
        state = request.GET.get("state")
        if not code or not state:
            return HttpResponse(
                _HTML.format(body="<h2>Missing code or state</h2>"),
                status=400,
                content_type="text/html",
            )

        try:
            payload = signing.loads(state, salt=STATE_SALT, max_age=600)
        except signing.BadSignature:
            return HttpResponse(
                _HTML.format(body="<h2>Invalid or expired request</h2><p>Try connecting again from the app.</p>"),
                status=400,
                content_type="text/html",
            )

        from apps.accounts.models import User

        try:
            user = User.objects.get(id=payload["user_id"])
        except User.DoesNotExist:
            return HttpResponse(
                _HTML.format(body="<h2>User not found</h2>"),
                status=400,
                content_type="text/html",
            )

        try:
            tokens = exchange_code_for_tokens(code)
        except GoogleCalendarError as exc:
            return HttpResponse(
                _HTML.format(body=f"<h2>Connection failed</h2><p>{exc}</p>"),
                status=502,
                content_type="text/html",
            )

        refresh_token = tokens.get("refresh_token")
        existing = GoogleCalendarConnection.objects.filter(owner=user).first()
        if not refresh_token and not existing:
            return HttpResponse(
                _HTML.format(
                    body="<h2>Connection failed</h2>"
                    "<p>Google didn't grant offline access. Try connecting again.</p>"
                ),
                status=502,
                content_type="text/html",
            )

        GoogleCalendarConnection.objects.update_or_create(
            owner=user,
            defaults={
                "access_token": tokens["access_token"],
                "token_expiry": timezone.now()
                + timedelta(seconds=tokens.get("expires_in", 3600)),
                **({"refresh_token": refresh_token} if refresh_token else {}),
            },
        )
        return HttpResponse(
            _HTML.format(
                body="<h2>Google Calendar connected 🎉</h2>"
                "<p>You can close this tab and return to the app.</p>"
            ),
            content_type="text/html",
        )
