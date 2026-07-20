from django.urls import path

from .views import (
    ProjectDetailView,
    ProjectListCreateView,
    ProjectResourceListCreateView,
    ProjectTaskListView,
    ResourceDetailView,
    ResourceDownloadView,
    TaskDetailView,
)

urlpatterns = [
    path("", ProjectListCreateView.as_view(), name="project-list-create"),
    path("<int:pk>/", ProjectDetailView.as_view(), name="project-detail"),
    path("<int:pk>/tasks/", ProjectTaskListView.as_view(), name="project-task-list"),
    path("tasks/<int:pk>/", TaskDetailView.as_view(), name="task-detail"),
    path(
        "<int:pk>/resources/",
        ProjectResourceListCreateView.as_view(),
        name="project-resource-list-create",
    ),
    path("resources/<int:pk>/", ResourceDetailView.as_view(), name="resource-detail"),
    path(
        "resources/<int:pk>/download/",
        ResourceDownloadView.as_view(),
        name="resource-download",
    ),
]
