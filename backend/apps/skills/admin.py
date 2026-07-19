from django.contrib import admin

from .models import Milestone, Roadmap


class MilestoneInline(admin.TabularInline):
    model = Milestone
    extra = 0


@admin.register(Roadmap)
class RoadmapAdmin(admin.ModelAdmin):
    list_display = ["title", "owner", "target_date", "created_at"]
    inlines = [MilestoneInline]


@admin.register(Milestone)
class MilestoneAdmin(admin.ModelAdmin):
    list_display = ["title", "roadmap", "status", "order"]
    list_filter = ["status"]
