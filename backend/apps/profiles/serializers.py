from rest_framework import serializers

from .models import Resume


class ResumeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Resume
        fields = ["filename", "uploaded_at"]


class TailorCVSerializer(serializers.Serializer):
    job_title = serializers.CharField(max_length=255)
    job_org = serializers.CharField(max_length=255, required=False, allow_blank=True)
    job_description = serializers.CharField()
