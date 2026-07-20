from django.urls import path

from .views import ResumeView, TailorResumeView

urlpatterns = [
    path("resume/", ResumeView.as_view(), name="resume"),
    path("resume/tailor/", TailorResumeView.as_view(), name="resume-tailor"),
]
