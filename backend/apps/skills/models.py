from django.conf import settings
from django.db import models


class Roadmap(models.Model):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="roadmaps"
    )
    title = models.CharField(max_length=255)
    target_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "roadmaps"
        ordering = ["-created_at"]

    def __str__(self):
        return self.title


class Milestone(models.Model):
    STATUS_CHOICES = [
        ("todo", "todo"),
        ("in_progress", "in_progress"),
        ("done", "done"),
    ]

    roadmap = models.ForeignKey(Roadmap, on_delete=models.CASCADE, related_name="milestones")
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    order = models.PositiveIntegerField(default=0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="todo")
    target_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "milestones"
        ordering = ["order"]

    def __str__(self):
        return f"{self.roadmap_id}: {self.title}"
