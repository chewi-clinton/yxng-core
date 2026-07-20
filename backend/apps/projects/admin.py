from django.contrib import admin

from .models import Project, Resource, Task


class TaskInline(admin.TabularInline):
    model = Task
    extra = 0


class ResourceInline(admin.TabularInline):
    model = Resource
    extra = 0
    exclude = ["file"]


@admin.register(Project)
class ProjectAdmin(admin.ModelAdmin):
    list_display = ["title", "owner", "start_date", "target_end_date", "created_at"]
    inlines = [TaskInline, ResourceInline]


@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = ["title", "project", "status", "order", "scheduled_start"]
    list_filter = ["status"]


@admin.register(Resource)
class ResourceAdmin(admin.ModelAdmin):
    list_display = ["title", "project", "kind", "created_at"]
    list_filter = ["kind"]
    exclude = ["file"]
