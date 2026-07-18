from django.urls import path

from .views import LinkedPlatformDetailView, LinkedPlatformListCreateView

urlpatterns = [
    path("", LinkedPlatformListCreateView.as_view(), name="linked-platform-list-create"),
    path("<int:pk>/", LinkedPlatformDetailView.as_view(), name="linked-platform-detail"),
]
