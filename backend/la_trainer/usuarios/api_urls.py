from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import api_views
from . import ia_views

urlpatterns = [
    # ─── Autenticación ───────────────────────────────────────
    path('registro/', api_views.RegistroAPIView.as_view(), name='api_registro'),
    path('login/', api_views.LoginAPIView.as_view(), name='api_login'),
    path('logout/', api_views.LogoutAPIView.as_view(), name='api_logout'),
    path('avatares/', api_views.AvatarListAPIView.as_view(), name='api_avatares'),
    path('token/refresh/', TokenRefreshView.as_view(), name='api_token_refresh'),

    # ─── Perfil y onboarding ─────────────────────────────────
    path('perfil/', api_views.PerfilAPIView.as_view(), name='api_perfil'),
    path('onboarding/', api_views.OnboardingAPIView.as_view(), name='api_onboarding'),

    # ─── Ejercicios ──────────────────────────────────────────
    path('ejercicios/', api_views.EjercicioListAPIView.as_view(), name='api_ejercicios'),
    path('ejercicios/<int:pk>/', api_views.EjercicioDetalleAPIView.as_view(), name='api_ejercicio_detalle'),

    # ─── Planes entrenamiento (específicas antes de <pk>) ────
    path('planes/entrenamiento/', api_views.PlanEntrenamientoAPIView.as_view(), name='api_planes_entrenamiento'),
    path('planes/entrenamiento/activo/', api_views.PlanActivoAPIView.as_view(), name='api_plan_activo'),
    path('planes/entrenamiento/completar/', api_views.CompletarSesionAPIView.as_view(), name='api_completar_sesion'),
    path('planes/entrenamiento/<int:pk>/', api_views.PlanEntrenamientoDetalleAPIView.as_view(), name='api_plan_entrenamiento_detalle'),
    path('planes/entrenamiento/<int:pk>/rutina/', api_views.RutinaEjercicioAPIView.as_view(), name='api_rutina_ejercicio'),

    # ─── Planes alimentación (específicas antes de <pk>) ─────
    path('planes/alimentacion/', api_views.PlanAlimentacionAPIView.as_view(), name='api_planes_alimentacion'),
    path('planes/alimentacion/activo/', api_views.PlanAlimentacionActivoAPIView.as_view(), name='api_plan_alimentacion_activo'),
    path('planes/alimentacion/completar/', ia_views.CompletarPlanAlimentacionAPIView.as_view(), name='api_completar_plan_alimentacion'),
    path('planes/alimentacion/<int:pk>/', api_views.PlanAlimentacionDetalleAPIView.as_view(), name='api_plan_alimentacion_detalle'),
    path('planes/alimentacion/<int:pk>/comidas/', api_views.RutinaComidaAPIView.as_view(), name='api_rutina_comida'),

    # ─── Progreso de peso corporal ───────────────────────────
    path('progreso/', api_views.ProgresoAPIView.as_view(), name='api_progreso'),
    path('progreso/<int:pk>/', api_views.ProgresoDetalleAPIView.as_view(), name='api_progreso_detalle'),

    # ─── Comidas base ────────────────────────────────────────
    path('comidas/', api_views.ComidaAPIView.as_view(), name='api_comidas'),
    path('comidas/<int:pk>/', api_views.ComidaDetalleAPIView.as_view(), name='api_comida_detalle'),

    # ─── IA ──────────────────────────────────────────────────
    path('ia/plan/entrenamiento/', ia_views.GenerarPlanEntrenamientoAPIView.as_view(), name='api_ia_plan_entrenamiento'),
    path('ia/plan/alimentacion/', ia_views.GenerarPlanAlimentacionAPIView.as_view(), name='api_ia_plan_alimentacion'),
    path('ia/progreso/', ia_views.AnalizarProgresoAPIView.as_view(), name='api_ia_progreso'),
    path('ia/coach/', ia_views.ChatCoachAPIView.as_view(), name='api_ia_coach'),
    path('ia/historial/', ia_views.HistorialConversacionAPIView.as_view(), name='api_ia_historial'),

    # ─── Actividad (calendario de constancia) ────────────────
    path('actividad/', api_views.RegistroActividadAPIView.as_view(), name='api_actividad'),

    # ─── Progreso de alimentación ────────────────────────────
    path('progreso/alimentacion/', api_views.ProgresoAlimentacionAPIView.as_view(), name='api_progreso_alimentacion'),
    path('progreso/alimentacion/<int:pk>/', api_views.ProgresoAlimentacionDetalleAPIView.as_view(), name='api_progreso_alimentacion_detalle'),

    # ─── Sesión de entrenamiento en tiempo real ───────────────
    path('sesion/iniciar/', api_views.IniciarSesionAPIView.as_view(), name='api_sesion_iniciar'),
    path('sesion/activa/', api_views.SesionActivaAPIView.as_view(), name='api_sesion_activa'),
    path('sesion/<int:sesion_id>/ejercicio/<int:ejercicio_sesion_id>/completar/', api_views.CompletarEjercicioAPIView.as_view(), name='api_completar_ejercicio'),

    # ─── NUEVO: Acceso y progreso ─────────────────────────────
    # Llamar al abrir la app — registra acceso, actualiza racha, devuelve estado del día
    path('acceso/', api_views.RegistrarAccesoAPIView.as_view(), name='api_acceso'),

    # Dashboard de progreso completo (sin IA)
    # Con análisis IA: GET /api/progreso/resumen/?ia=true
    path('progreso/resumen/', api_views.ResumenProgresoAPIView.as_view(), name='api_progreso_resumen'),

    # Calendario mensual de constancia
    # GET /api/progreso/calendario/           → mes actual
    # GET /api/progreso/calendario/?año=2025&mes=3  → mes específico
    path('progreso/calendario/', api_views.CalendarioProgresoAPIView.as_view(), name='api_progreso_calendario'),
]