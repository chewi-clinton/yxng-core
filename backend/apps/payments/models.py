from django.conf import settings
from django.db import models


class LinkedPlatform(models.Model):
    SOURCE_CHOICES = [
        ("manual", "manual"),
        ("extension", "extension"),
    ]

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="linked_platforms"
    )
    name = models.CharField(max_length=255)
    card_label = models.CharField(max_length=100, blank=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    currency = models.CharField(max_length=8, default="usd")
    renews_on = models.DateField()
    source_url = models.URLField(blank=True)
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default="manual")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "linked_platforms"
        ordering = ["renews_on"]

    def __str__(self):
        return f"{self.name} ({self.owner_id})"
