from rest_framework import serializers

from .models import Project, Resource, Task


class ProjectCreateSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=255)
    description = serializers.CharField(required=False, allow_blank=True, default="")
    tech_stack = serializers.ListField(
        child=serializers.CharField(), required=False, default=list
    )
    start_date = serializers.DateField()
    target_end_date = serializers.DateField(required=False, allow_null=True)
    consider_other_projects = serializers.BooleanField(required=False, default=False)


class TaskSerializer(serializers.ModelSerializer):
    class Meta:
        model = Task
        fields = [
            "id",
            "title",
            "description",
            "estimated_duration",
            "order",
            "status",
            "scheduled_start",
            "scheduled_end",
            "ai_generated",
        ]


class TaskUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Task
        fields = [
            "title",
            "description",
            "estimated_duration",
            "order",
            "status",
            "scheduled_start",
            "scheduled_end",
        ]
        extra_kwargs = {field: {"required": False} for field in fields}


class ProjectListSerializer(serializers.ModelSerializer):
    task_count = serializers.IntegerField(source="tasks.count", read_only=True)

    class Meta:
        model = Project
        fields = [
            "id",
            "title",
            "description",
            "tech_stack",
            "start_date",
            "target_end_date",
            "task_count",
            "created_at",
        ]


class ResourceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Resource
        fields = ["id", "kind", "title", "url", "filename", "content_type", "created_at"]


class ProjectDetailSerializer(serializers.ModelSerializer):
    tasks = TaskSerializer(many=True, read_only=True)
    resources = ResourceSerializer(many=True, read_only=True)

    class Meta:
        model = Project
        fields = [
            "id",
            "title",
            "description",
            "tech_stack",
            "start_date",
            "target_end_date",
            "consider_other_projects",
            "tasks",
            "resources",
            "created_at",
            "updated_at",
        ]
