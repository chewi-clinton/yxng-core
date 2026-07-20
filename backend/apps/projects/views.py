from django.db import transaction
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.schedule.services.naive_scheduler import schedule_tasks

from .models import Project, Resource, Task
from .serializers import (
    ProjectCreateSerializer,
    ProjectDetailSerializer,
    ProjectListSerializer,
    ResourceSerializer,
    TaskSerializer,
    TaskUpdateSerializer,
)
from .services.ai_client import AIServiceError, get_task_breakdown

MAX_RESOURCE_BYTES = 10 * 1024 * 1024


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


class ProjectResourceListCreateView(generics.ListCreateAPIView):
    serializer_class = ResourceSerializer

    def get_queryset(self):
        return Resource.objects.filter(
            project_id=self.kwargs["pk"], project__owner=self.request.user
        )

    def create(self, request, *args, **kwargs):
        project = get_object_or_404(Project, pk=self.kwargs["pk"], owner=request.user)
        kind = request.data.get("kind")
        title = (request.data.get("title") or "").strip()
        if not title:
            return Response(
                {"detail": "title is required"}, status=status.HTTP_400_BAD_REQUEST
            )

        if kind == "link":
            url = (request.data.get("url") or "").strip()
            if not url:
                return Response(
                    {"detail": "url is required for link resources"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            resource = Resource.objects.create(
                project=project, kind="link", title=title, url=url
            )
        elif kind == "file":
            upload = request.FILES.get("file")
            if upload is None:
                return Response(
                    {"detail": "file is required for file resources"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if upload.size > MAX_RESOURCE_BYTES:
                return Response(
                    {"detail": "File is too large (max 10MB)"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            resource = Resource.objects.create(
                project=project,
                kind="file",
                title=title,
                file=upload.read(),
                filename=upload.name,
                content_type=upload.content_type or "",
            )
        else:
            return Response(
                {"detail": "kind must be 'link' or 'file'"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(ResourceSerializer(resource).data, status=status.HTTP_201_CREATED)


class ResourceDetailView(generics.DestroyAPIView):
    def get_queryset(self):
        return Resource.objects.filter(project__owner=self.request.user)


class ResourceDownloadView(APIView):
    def get(self, request, pk):
        resource = get_object_or_404(
            Resource, pk=pk, project__owner=request.user, kind="file"
        )
        return HttpResponse(
            bytes(resource.file),
            content_type=resource.content_type or "application/octet-stream",
            headers={"Content-Disposition": f'inline; filename="{resource.filename}"'},
        )
