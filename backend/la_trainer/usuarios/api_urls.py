from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from . import api_views
from . import ia_views

urlpatterns = [
    # Autenticación
    path('registro/', api_views.RegistroAPIView.as_view(), name='api_registro'),
    path('login/', TokenObtainPairView.as_view(), name='api_login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='api_token_refresh'),

    # Perfil
    path('perfil/', api_views.PerfilAPIView.as_view(), name='api_perfil'),

    # Ejercicios
    path('ejercicios/', api_views.EjercicioListAPIView.as_view(), name='api_ejercicios'),
    path('ejercicios/<int:pk>/', api_views.EjercicioDetalleAPIView.as_view(), name='api_ejercicio_detalle'),

    # Planes entrenamiento
    path('planes/entrenamiento/', api_views.PlanEntrenamientoAPIView.as_view(), name='api_planes_entrenamiento'),
    path('planes/entrenamiento/<int:pk>/', api_views.PlanEntrenamientoDetalleAPIView.as_view(), name='api_plan_entrenamiento_detalle'),

    # Planes alimentacion
    path('planes/alimentacion/', api_views.PlanAlimentacionAPIView.as_view(), name='api_planes_alimentacion'),
    path('planes/alimentacion/<int:pk>/', api_views.PlanAlimentacionDetalleAPIView.as_view(), name='api_plan_alimentacion_detalle'),

    # Progreso
    path('progreso/', api_views.ProgresoAPIView.as_view(), name='api_progreso'),
    path('progreso/<int:pk>/', api_views.ProgresoDetalleAPIView.as_view(), name='api_progreso_detalle'),

    # Comidas
    path('comidas/', api_views.ComidaAPIView.as_view(), name='api_comidas'),
    path('comidas/<int:pk>/', api_views.ComidaDetalleAPIView.as_view(), name='api_comida_detalle'),

    # Onboarding
    path('onboarding/', api_views.OnboardingAPIView.as_view(), name='api_onboarding'),

    # IA
    path('ia/plan/entrenamiento/', ia_views.GenerarPlanEntrenamientoAPIView.as_view(), name='api_ia_plan_entrenamiento'),
    path('ia/plan/alimentacion/', ia_views.GenerarPlanAlimentacionAPIView.as_view(), name='api_ia_plan_alimentacion'),
    path('ia/progreso/', ia_views.AnalizarProgresoAPIView.as_view(), name='api_ia_progreso'),
    path('ia/coach/', ia_views.ChatCoachAPIView.as_view(), name='api_ia_coach'),
    path('ia/historial/', ia_views.HistorialConversacionAPIView.as_view(), name='api_ia_historial'),
]