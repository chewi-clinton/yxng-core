from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import User

from .models import Resume
from .services.ai_client import AIServiceError

MINIMAL_PDF = (
    b"%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n"
    b"2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n"
    b"3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]>>endobj\n"
    b"trailer<</Root 1 0 R>>"
)


class ResumeUploadTests(APITestCase):
    url = "/api/v1/profile/resume/"

    def setUp(self):
        self.user = User.objects.create_user(username="clinton", password="pass12345!")
        self.client.force_authenticate(user=self.user)

    def test_get_returns_null_when_no_resume(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIsNone(response.data)

    def test_upload_pdf_creates_resume(self):
        upload = SimpleUploadedFile("resume.pdf", MINIMAL_PDF, content_type="application/pdf")
        response = self.client.post(self.url, {"file": upload}, format="multipart")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        resume = Resume.objects.get(owner=self.user)
        self.assertEqual(resume.filename, "resume.pdf")
        self.assertEqual(bytes(resume.file), MINIMAL_PDF)

    def test_upload_rejects_non_pdf(self):
        upload = SimpleUploadedFile("resume.txt", b"not a pdf", content_type="text/plain")
        response = self.client.post(self.url, {"file": upload}, format="multipart")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_delete_removes_resume(self):
        Resume.objects.create(owner=self.user, filename="r.pdf", file=MINIMAL_PDF)
        response = self.client.delete(self.url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Resume.objects.filter(owner=self.user).exists())

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class TailorResumeTests(APITestCase):
    url = "/api/v1/profile/resume/tailor/"

    def setUp(self):
        self.user = User.objects.create_user(username="clinton", password="pass12345!")
        self.client.force_authenticate(user=self.user)

    def test_requires_resume_first(self):
        response = self.client.post(
            self.url,
            {"job_title": "Engineer", "job_description": "Build things"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    @patch(
        "apps.profiles.views.get_tailored_resume",
        return_value="Tailored resume text",
    )
    def test_tailors_resume_when_uploaded(self, mock_tailor):
        Resume.objects.create(
            owner=self.user,
            filename="r.pdf",
            file=MINIMAL_PDF,
            extracted_text="Experienced engineer with Python skills.",
        )
        response = self.client.post(
            self.url,
            {"job_title": "Backend Engineer", "job_org": "Acme", "job_description": "Python role"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["tailored_resume"], "Tailored resume text")
        mock_tailor.assert_called_once()

    @patch(
        "apps.profiles.views.get_tailored_resume",
        side_effect=AIServiceError("boom"),
    )
    def test_ai_failure_returns_502(self, mock_tailor):
        Resume.objects.create(
            owner=self.user,
            filename="r.pdf",
            file=MINIMAL_PDF,
            extracted_text="Experienced engineer.",
        )
        response = self.client.post(
            self.url,
            {"job_title": "Engineer", "job_description": "Build things"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_502_BAD_GATEWAY)

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        response = self.client.post(
            self.url,
            {"job_title": "Engineer", "job_description": "Build things"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
