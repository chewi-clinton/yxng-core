from rest_framework import generics

from .models import LinkedPlatform
from .serializers import LinkedPlatformSerializer


class LinkedPlatformListCreateView(generics.ListCreateAPIView):
    serializer_class = LinkedPlatformSerializer

    def get_queryset(self):
        return LinkedPlatform.objects.filter(owner=self.request.user)

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)


class LinkedPlatformDetailView(generics.RetrieveDestroyAPIView):
    serializer_class = LinkedPlatformSerializer

    def get_queryset(self):
        return LinkedPlatform.objects.filter(owner=self.request.user)
