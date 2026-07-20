from django.conf import settings
from django.db import models


class Resume(models.Model):
    owner = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="resume"
    )
    filename = models.CharField(max_length=255)
    file = models.BinaryField()
    extracted_text = models.TextField(blank=True)
    uploaded_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "resumes"

    def __str__(self):
        return f"{self.owner_id}: {self.filename}"
