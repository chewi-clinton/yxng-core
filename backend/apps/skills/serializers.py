from rest_framework import serializers

from .models import Milestone, Roadmap


class RoadmapCreateSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=255)
    target_date = serializers.DateField(required=False, allow_null=True)


class MilestoneSerializer(serializers.ModelSerializer):
    class Meta:
        model = Milestone
        fields = ["id", "title", "description", "order", "status"]


class MilestoneUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Milestone
        fields = ["status"]


class RoadmapListSerializer(serializers.ModelSerializer):
    milestone_count = serializers.IntegerField(source="milestones.count", read_only=True)
    completed_count = serializers.SerializerMethodField()

    class Meta:
        model = Roadmap
        fields = [
            "id",
            "title",
            "target_date",
            "milestone_count",
            "completed_count",
            "created_at",
        ]

    def get_completed_count(self, obj):
        return obj.milestones.filter(status="done").count()


class RoadmapDetailSerializer(serializers.ModelSerializer):
    milestones = MilestoneSerializer(many=True, read_only=True)

    class Meta:
        model = Roadmap
        fields = [
            "id",
            "title",
            "target_date",
            "milestones",
            "created_at",
            "updated_at",
        ]
