from rest_framework import status
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Resume
from .serializers import ResumeSerializer, TailorCVSerializer
from .services.ai_client import AIServiceError, get_tailored_resume
from .services.pdf_text import extract_pdf_text

MAX_RESUME_BYTES = 5 * 1024 * 1024


class ResumeView(APIView):
    parser_classes = [MultiPartParser]

    def get(self, request):
        try:
            resume = request.user.resume
        except Resume.DoesNotExist:
            return Response(None)
        return Response(ResumeSerializer(resume).data)

    def post(self, request):
        upload = request.FILES.get("file")
        if upload is None:
            return Response(
                {"detail": "file is required"}, status=status.HTTP_400_BAD_REQUEST
            )
        if upload.content_type != "application/pdf":
            return Response(
                {"detail": "Only PDF files are supported"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if upload.size > MAX_RESUME_BYTES:
            return Response(
                {"detail": "File is too large (max 5MB)"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        data = upload.read()
        Resume.objects.update_or_create(
            owner=request.user,
            defaults={
                "filename": upload.name,
                "file": data,
                "extracted_text": extract_pdf_text(data),
            },
        )
        return Response(
            ResumeSerializer(request.user.resume).data, status=status.HTTP_201_CREATED
        )

    def delete(self, request):
        Resume.objects.filter(owner=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class TailorResumeView(APIView):
    def post(self, request):
        try:
            resume = request.user.resume
        except Resume.DoesNotExist:
            return Response(
                {"detail": "Upload a resume first"}, status=status.HTTP_400_BAD_REQUEST
            )
        if not resume.extracted_text:
            return Response(
                {"detail": "Couldn't read text from your uploaded resume"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = TailorCVSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            tailored = get_tailored_resume(
                resume.extracted_text,
                data["job_title"],
                data.get("job_org", ""),
                data["job_description"],
            )
        except AIServiceError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        return Response({"tailored_resume": tailored}, status=status.HTTP_200_OK)
