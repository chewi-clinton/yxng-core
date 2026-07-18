from rest_framework import serializers

from .models import LinkedPlatform


class LinkedPlatformSerializer(serializers.ModelSerializer):
    class Meta:
        model = LinkedPlatform
        fields = [
            "id",
            "name",
            "card_label",
            "amount",
            "currency",
            "renews_on",
            "source_url",
            "source",
            "created_at",
        ]
        extra_kwargs = {
            "source": {"required": False},
        }
