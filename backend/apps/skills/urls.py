from django.urls import path

from .views import MilestoneDetailView, RoadmapDetailView, RoadmapListCreateView

urlpatterns = [
    path("", RoadmapListCreateView.as_view(), name="roadmap-list-create"),
    path("<int:pk>/", RoadmapDetailView.as_view(), name="roadmap-detail"),
    path("milestones/<int:pk>/", MilestoneDetailView.as_view(), name="milestone-detail"),
]
