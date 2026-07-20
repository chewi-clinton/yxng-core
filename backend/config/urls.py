from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
)

from apps.common.views import HealthCheckView

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/health/", HealthCheckView.as_view(), name="health-check"),
    path("api/v1/auth/", include("apps.accounts.urls")),
    path("api/v1/projects/", include("apps.projects.urls")),
    path("api/v1/payments/", include("apps.payments.urls")),
    path("api/v1/skills/", include("apps.skills.urls")),
    path("api/v1/profile/", include("apps.profiles.urls")),
    path("api/v1/calendar/", include("apps.calendar_sync.urls")),
    path("api/v1/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/v1/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
]
