from django.conf import settings
from django.db import models


class Project(models.Model):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="projects"
    )
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    tech_stack = models.JSONField(default=list, blank=True)
    start_date = models.DateField()
    target_end_date = models.DateField(null=True, blank=True)
    # Phase 2 scheduler hook: when True, the calendar-aware engine will also
    # avoid slots already claimed by the owner's other projects. Ignored by
    # the naive scheduler used in Phase 1.
    consider_other_projects = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "projects"
        ordering = ["-created_at"]

    def __str__(self):
        return self.title


class Task(models.Model):
    STATUS_CHOICES = [
        ("todo", "todo"),
        ("in_progress", "in_progress"),
        ("done", "done"),
        ("blocked", "blocked"),
    ]

    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="tasks")
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    estimated_duration = models.PositiveIntegerField(help_text="Minutes")
    order = models.PositiveIntegerField(default=0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="todo")
    scheduled_start = models.DateTimeField(null=True, blank=True)
    scheduled_end = models.DateTimeField(null=True, blank=True)
    ai_generated = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "tasks"
        ordering = ["order"]

    def __str__(self):
        return f"{self.project_id}: {self.title}"


class Resource(models.Model):
    KIND_CHOICES = [
        ("link", "link"),
        ("file", "file"),
    ]

    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="resources")
    kind = models.CharField(max_length=10, choices=KIND_CHOICES)
    title = models.CharField(max_length=255)
    url = models.URLField(blank=True)
    file = models.BinaryField(null=True, blank=True)
    filename = models.CharField(max_length=255, blank=True)
    content_type = models.CharField(max_length=100, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "project_resources"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.project_id}: {self.title}"
