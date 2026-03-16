from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from . import api_views

urlpatterns = [
    # Autenticación
    path('registro/', api_views.RegistroAPIView.as_view(), name='api_registro'),
    path('login/', TokenObtainPairView.as_view(), name='api_login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='api_token_refresh'),

    # Perfil
    path('perfil/', api_views.PerfilAPIView.as_view(), name='api_perfil'),

    # Ejercicios
    path('ejercicios/', api_views.EjercicioListAPIView.as_view(), name='api_ejercicios'),

    # Planes
    path('planes/entrenamiento/', api_views.PlanEntrenamientoAPIView.as_view(), name='api_planes_entrenamiento'),
    path('planes/alimentacion/', api_views.PlanAlimentacionAPIView.as_view(), name='api_planes_alimentacion'),

    # Progreso
    path('progreso/', api_views.ProgresoAPIView.as_view(), name='api_progreso'),
]