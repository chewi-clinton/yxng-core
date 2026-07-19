from django.db import transaction
from rest_framework import generics, status
from rest_framework.response import Response

from .models import Milestone, Roadmap
from .serializers import (
    MilestoneUpdateSerializer,
    RoadmapCreateSerializer,
    RoadmapDetailSerializer,
    RoadmapListSerializer,
)
from .services.ai_client import AIServiceError, get_roadmap_breakdown


class RoadmapListCreateView(generics.ListCreateAPIView):
    def get_queryset(self):
        return Roadmap.objects.filter(owner=self.request.user)

    def get_serializer_class(self):
        if self.request.method == "POST":
            return RoadmapCreateSerializer
        return RoadmapListSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            with transaction.atomic():
                roadmap = Roadmap.objects.create(
                    owner=request.user, **serializer.validated_data
                )
                breakdown = get_roadmap_breakdown(roadmap.title, roadmap.target_date)
                Milestone.objects.bulk_create(
                    [
                        Milestone(
                            roadmap=roadmap,
                            title=m["title"],
                            description=m.get("description", ""),
                            order=i,
                        )
                        for i, m in enumerate(breakdown)
                    ]
                )
        except AIServiceError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        return Response(
            RoadmapDetailSerializer(roadmap).data, status=status.HTTP_201_CREATED
        )


class RoadmapDetailView(generics.RetrieveDestroyAPIView):
    serializer_class = RoadmapDetailSerializer

    def get_queryset(self):
        return Roadmap.objects.filter(owner=self.request.user)


class MilestoneDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = MilestoneUpdateSerializer

    def get_queryset(self):
        return Milestone.objects.filter(roadmap__owner=self.request.user)
