from django.db import transaction
from rest_framework import generics, status
from rest_framework.response import Response

from apps.schedule.services.naive_scheduler import schedule_tasks

from .models import Project, Task
from .serializers import (
    ProjectCreateSerializer,
    ProjectDetailSerializer,
    ProjectListSerializer,
    TaskSerializer,
    TaskUpdateSerializer,
)
from .services.ai_client import AIServiceError, get_task_breakdown


class ProjectListCreateView(generics.ListCreateAPIView):
    def get_queryset(self):
        return Project.objects.filter(owner=self.request.user)

    def get_serializer_class(self):
        if self.request.method == "POST":
            return ProjectCreateSerializer
        return ProjectListSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            with transaction.atomic():
                project = Project.objects.create(
                    owner=request.user, **serializer.validated_data
                )
                breakdown = get_task_breakdown(project)
                slots = schedule_tasks(breakdown, project.start_date)
                Task.objects.bulk_create(
                    [
                        Task(
                            project=project,
                            title=t["title"],
                            description=t.get("description", ""),
                            estimated_duration=t["estimated_duration_minutes"],
                            order=i,
                            scheduled_start=slots[i][0],
                            scheduled_end=slots[i][1],
                        )
                        for i, t in enumerate(breakdown)
                    ]
                )
        except AIServiceError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        return Response(
            ProjectDetailSerializer(project).data, status=status.HTTP_201_CREATED
        )


class ProjectDetailView(generics.RetrieveDestroyAPIView):
    serializer_class = ProjectDetailSerializer

    def get_queryset(self):
        return Project.objects.filter(owner=self.request.user)


class ProjectTaskListView(generics.ListAPIView):
    serializer_class = TaskSerializer

    def get_queryset(self):
        return Task.objects.filter(
            project_id=self.kwargs["pk"], project__owner=self.request.user
        )


class TaskDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = TaskUpdateSerializer

    def get_queryset(self):
        return Task.objects.filter(project__owner=self.request.user)
