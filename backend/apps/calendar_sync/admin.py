from django.contrib import admin

from .models import GoogleCalendarConnection, SyncedEvent


@admin.register(GoogleCalendarConnection)
class GoogleCalendarConnectionAdmin(admin.ModelAdmin):
    list_display = ["owner", "connected_at", "token_expiry"]
    exclude = ["refresh_token", "access_token"]


@admin.register(SyncedEvent)
class SyncedEventAdmin(admin.ModelAdmin):
    list_display = ["owner", "source_type", "source_id", "google_event_id"]
    list_filter = ["source_type"]
