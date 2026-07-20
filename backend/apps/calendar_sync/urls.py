from django.urls import path

from .views import CallbackView, ConnectView, StatusView

urlpatterns = [
    path("connect/", ConnectView.as_view(), name="calendar-connect"),
    path("status/", StatusView.as_view(), name="calendar-status"),
    path("callback/", CallbackView.as_view(), name="calendar-callback"),
]
