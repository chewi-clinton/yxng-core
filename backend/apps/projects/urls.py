from django.urls import path

from .views import (
    ProjectDetailView,
    ProjectListCreateView,
    ProjectTaskListView,
    TaskDetailView,
)

urlpatterns = [
    path("", ProjectListCreateView.as_view(), name="project-list-create"),
    path("<int:pk>/", ProjectDetailView.as_view(), name="project-detail"),
    path("<int:pk>/tasks/", ProjectTaskListView.as_view(), name="project-task-list"),
    path("tasks/<int:pk>/", TaskDetailView.as_view(), name="task-detail"),
]
