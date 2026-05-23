from datetime import date, timedelta
import calendar

from rest_framework import status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import (
    Ejercicio, PlanEntrenamiento, PlanAlimentacion, Progreso,
    Comida, RutinaEjercicio, RutinaComida, RegistroActividad, ProgresoAlimentacion,
    SesionEntrenamiento, EjercicioSesion, RegistroAcceso
)
from .serializers import (
    RegistroSerializer, UsuarioSerializer, EjercicioSerializer,
    PlanEntrenamientoSerializer, PlanAlimentacionSerializer,
    ComidaSerializer, ProgresoSerializer, RutinaEjercicioSerializer,
    RutinaComidaSerializer, RegistroActividadSerializer, ProgresoAlimentacionSerializer,
    SesionEntrenamientoSerializer, EjercicioSesionSerializer
)


# ─── Autenticación ────────────────────────────────────────────

class RegistroAPIView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegistroSerializer(data=request.data)
        if serializer.is_valid():
            usuario = serializer.save()
            refresh = RefreshToken.for_user(usuario)
            return Response({
                'mensaje': 'Cuenta creada exitosamente!',
                'access': str(refresh.access_token),
                'refresh': str(refresh),
                'usuario': UsuarioSerializer(usuario).data
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ─── Perfil ───────────────────────────────────────────────────

class PerfilAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UsuarioSerializer(request.user)
        return Response(serializer.data)

    def put(self, request):
        serializer = UsuarioSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request):
        request.user.delete()
        return Response({'mensaje': 'Cuenta eliminada correctamente.'}, status=status.HTTP_200_OK)


# ─── Onboarding ───────────────────────────────────────────────

class OnboardingAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.peso and request.user.altura:
            return Response(
                {'error': 'El perfil basico ya fue completado. Para hacer cambios habla con el coach.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        serializer = UsuarioSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({
                'mensaje': 'Perfil basico completado! El coach te hara algunas preguntas mas.',
                'usuario': serializer.data
            })
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ─── Ejercicios ───────────────────────────────────────────────

class EjercicioListAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        ejercicios = Ejercicio.objects.all()
        serializer = EjercicioSerializer(ejercicios, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = EjercicioSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class EjercicioDetalleAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk):
        try:
            return Ejercicio.objects.get(pk=pk)
        except Ejercicio.DoesNotExist:
            return None

    def get(self, request, pk):
        ejercicio = self.get_object(pk)
        if not ejercicio:
            return Response({'error': 'Ejercicio no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = EjercicioSerializer(ejercicio)
        return Response(serializer.data)

    def put(self, request, pk):
        ejercicio = self.get_object(pk)
        if not ejercicio:
            return Response({'error': 'Ejercicio no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = EjercicioSerializer(ejercicio, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        ejercicio = self.get_object(pk)
        if not ejercicio:
            return Response({'error': 'Ejercicio no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        ejercicio.delete()
        return Response({'mensaje': 'Ejercicio eliminado correctamente.'}, status=status.HTTP_200_OK)


# ─── Planes de entrenamiento ──────────────────────────────────

class PlanEntrenamientoAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        planes = PlanEntrenamiento.objects.filter(usuario=request.user)
        serializer = PlanEntrenamientoSerializer(planes, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = PlanEntrenamientoSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(usuario=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class PlanActivoAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        plan = PlanEntrenamiento.objects.filter(
            usuario=request.user, activo=True
        ).last()

        if not plan:
            return Response({
                'tiene_plan_activo': False,
                'mensaje': 'No tienes un plan activo. Genera uno desde /api/ia/plan/entrenamiento/',
            })

        dias_semana = request.user.dias_entrenamiento or 3
        sesiones_totales = plan.duracion * dias_semana

        return Response({
            'tiene_plan_activo': True,
            'plan': PlanEntrenamientoSerializer(plan).data,
            'sesiones_completadas': plan.sesiones_completadas,
            'sesiones_totales': sesiones_totales,
            'sesiones_restantes': max(0, sesiones_totales - plan.sesiones_completadas),
            'porcentaje_completado': round(
                (plan.sesiones_completadas / sesiones_totales * 100) if sesiones_totales > 0 else 0, 1
            ),
        })


class PlanEntrenamientoDetalleAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, usuario):
        try:
            return PlanEntrenamiento.objects.get(pk=pk, usuario=usuario)
        except PlanEntrenamiento.DoesNotExist:
            return None

    def get(self, request, pk):
        plan = self.get_object(pk, request.user)
        if not plan:
            return Response({'error': 'Plan no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = PlanEntrenamientoSerializer(plan)
        return Response(serializer.data)

    def patch(self, request, pk):
        plan = self.get_object(pk, request.user)
        if not plan:
            return Response({'error': 'Plan no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        if not plan.activo:
            return Response({'error': 'Este plan ya está finalizado.'}, status=status.HTTP_400_BAD_REQUEST)
        plan.activo = False
        plan.save()
        return Response({'mensaje': 'Plan finalizado correctamente. Ya puedes generar uno nuevo.'})

    def put(self, request, pk):
        plan = self.get_object(pk, request.user)
        if not plan:
            return Response({'error': 'Plan no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = PlanEntrenamientoSerializer(plan, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        plan = self.get_object(pk, request.user)
        if not plan:
            return Response({'error': 'Plan no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        plan.delete()
        return Response({'mensaje': 'Plan eliminado correctamente.'}, status=status.HTTP_200_OK)


class RutinaEjercicioAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            plan = PlanEntrenamiento.objects.get(pk=pk, usuario=request.user)
            serializer = RutinaEjercicioSerializer(
                plan.rutina_ejercicios.all(), many=True
            )
            return Response(serializer.data)
        except PlanEntrenamiento.DoesNotExist:
            return Response(
                {'error': 'Plan no encontrado.'},
                status=status.HTTP_404_NOT_FOUND
            )


# ─── Planes de alimentación ───────────────────────────────────

class PlanAlimentacionAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        planes = PlanAlimentacion.objects.filter(usuario=request.user)
        serializer = PlanAlimentacionSerializer(planes, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = PlanAlimentacionSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(usuario=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class PlanAlimentacionActivoAPIView(APIView):
    """
    GET /api/planes/alimentacion/activo/
    Devuelve el plan activo con TODAS las comidas del dia (rutina_comidas),
    cada una con nombre, momento, macros, ingredientes, preparacion y
    tiempo de preparacion.
    Tambien incluye el progreso del dia actual para que Flutter sepa
    si el usuario ya registro su alimentacion hoy.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        plan = PlanAlimentacion.objects.filter(
            usuario=request.user, activo=True
        ).last()

        if not plan:
            plan_completado = PlanAlimentacion.objects.filter(
                usuario=request.user, completado=True
            ).last()
            if plan_completado:
                return Response({
                    'tiene_plan_activo': False,
                    'plan_completado': True,
                    'puede_generar_nuevo': True,
                    'mensaje': 'Completaste tu plan de alimentacion. Genera uno nuevo desde /api/ia/plan/alimentacion/',
                })
            return Response({
                'tiene_plan_activo': False,
                'plan_completado': False,
                'puede_generar_nuevo': True,
                'mensaje': 'No tienes un plan de alimentacion activo. Genera uno desde /api/ia/plan/alimentacion/',
            })

        progreso_hoy = ProgresoAlimentacion.objects.filter(
            usuario=request.user, fecha=date.today()
        ).first()

        return Response({
            'tiene_plan_activo': True,
            'plan': PlanAlimentacionSerializer(plan).data,
            'dias_completados': plan.dias_completados,
            'duracion_dias': plan.duracion_dias,
            'dias_restantes': max(0, plan.duracion_dias - plan.dias_completados),
            'porcentaje_completado': round(
                (plan.dias_completados / plan.duracion_dias * 100) if plan.duracion_dias > 0 else 0, 1
            ),
            'ya_registro_hoy': progreso_hoy is not None,
            'progreso_hoy': ProgresoAlimentacionSerializer(progreso_hoy).data if progreso_hoy else None,
        })


class PlanAlimentacionDetalleAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, usuario):
        try:
            return PlanAlimentacion.objects.get(pk=pk, usuario=usuario)
        except PlanAlimentacion.DoesNotExist:
            return None

    def get(self, request, pk):
        plan = self.get_object(pk, request.user)
        if not plan:
            return Response({'error': 'Plan no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = PlanAlimentacionSerializer(plan)
        return Response(serializer.data)

    def patch(self, request, pk):
        plan = self.get_object(pk, request.user)
        if not plan:
            return Response({'error': 'Plan no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        if not plan.activo:
            return Response({'error': 'Este plan ya esta finalizado.'}, status=status.HTTP_400_BAD_REQUEST)
        plan.activo = False
        plan.save()
        return Response({'mensaje': 'Plan de alimentacion finalizado. Ya puedes generar uno nuevo.'})

    def put(self, request, pk):
        plan = self.get_object(pk, request.user)
        if not plan:
            return Response({'error': 'Plan no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = PlanAlimentacionSerializer(plan, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        plan = self.get_object(pk, request.user)
        if not plan:
            return Response({'error': 'Plan no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        plan.delete()
        return Response({'mensaje': 'Plan eliminado correctamente.'}, status=status.HTTP_200_OK)


class RutinaComidaAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            plan = PlanAlimentacion.objects.get(pk=pk, usuario=request.user)
            serializer = RutinaComidaSerializer(
                plan.rutina_comidas.all(), many=True
            )
            return Response(serializer.data)
        except PlanAlimentacion.DoesNotExist:
            return Response(
                {'error': 'Plan no encontrado.'},
                status=status.HTTP_404_NOT_FOUND
            )


# ─── Comidas base ─────────────────────────────────────────────

class ComidaAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        comidas = Comida.objects.all()
        serializer = ComidaSerializer(comidas, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = ComidaSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ComidaDetalleAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk):
        try:
            return Comida.objects.get(pk=pk)
        except Comida.DoesNotExist:
            return None

    def get(self, request, pk):
        comida = self.get_object(pk)
        if not comida:
            return Response({'error': 'Comida no encontrada.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = ComidaSerializer(comida)
        return Response(serializer.data)

    def put(self, request, pk):
        comida = self.get_object(pk)
        if not comida:
            return Response({'error': 'Comida no encontrada.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = ComidaSerializer(comida, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        comida = self.get_object(pk)
        if not comida:
            return Response({'error': 'Comida no encontrada.'}, status=status.HTTP_404_NOT_FOUND)
        comida.delete()
        return Response({'mensaje': 'Comida eliminada correctamente.'}, status=status.HTTP_200_OK)


# ─── Progreso de peso corporal ────────────────────────────────

class ProgresoAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        progresos = Progreso.objects.filter(usuario=request.user)
        serializer = ProgresoSerializer(progresos, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = ProgresoSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(usuario=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ProgresoDetalleAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, usuario):
        try:
            return Progreso.objects.get(pk=pk, usuario=usuario)
        except Progreso.DoesNotExist:
            return None

    def put(self, request, pk):
        progreso = self.get_object(pk, request.user)
        if not progreso:
            return Response({'error': 'Registro no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = ProgresoSerializer(progreso, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        progreso = self.get_object(pk, request.user)
        if not progreso:
            return Response({'error': 'Registro no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        progreso.delete()
        return Response({'mensaje': 'Registro eliminado correctamente.'}, status=status.HTTP_200_OK)


# ─── Completar sesion de entrenamiento (endpoint legacy) ──────

class CompletarSesionAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from django.utils import timezone

        plan = PlanEntrenamiento.objects.filter(
            usuario=request.user, activo=True
        ).last()

        if not plan:
            return Response(
                {'error': 'No tienes un plan activo. Genera uno desde /api/ia/plan/entrenamiento/'},
                status=status.HTTP_404_NOT_FOUND
            )

        dias_semana = request.user.dias_entrenamiento or 3
        sesiones_totales = plan.duracion * dias_semana
        plan.sesiones_completadas += 1

        if plan.sesiones_completadas >= sesiones_totales:
            plan.completado = True
            plan.activo = False
            plan.fecha_completado = timezone.now()
            mensaje = (
                f'Felicitaciones! Completaste el plan de {plan.duracion} semanas. '
                'Ya puedes generar un nuevo plan desde /api/ia/plan/entrenamiento/'
            )
        else:
            restantes = sesiones_totales - plan.sesiones_completadas
            mensaje = (
                f'Sesion registrada! Llevas {plan.sesiones_completadas} de {sesiones_totales} sesiones. '
                f'Te faltan {restantes} sesion(es) para completar el plan.'
            )

        plan.save()

        RegistroActividad.objects.create(
            usuario=request.user,
            plan=plan,
            sesion_numero=plan.sesiones_completadas,
            notas=request.data.get('notas', '')
        )

        return Response({
            'mensaje': mensaje,
            'sesiones_completadas': plan.sesiones_completadas,
            'sesiones_totales': sesiones_totales,
            'sesiones_restantes': max(0, sesiones_totales - plan.sesiones_completadas),
            'porcentaje_completado': round(
                (plan.sesiones_completadas / sesiones_totales * 100) if sesiones_totales > 0 else 0, 1
            ),
            'plan_completado': plan.completado,
            'plan_activo': plan.activo,
        }, status=status.HTTP_200_OK)


# ─── Registro de actividad ────────────────────────────────────

class RegistroActividadAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        registros = RegistroActividad.objects.filter(usuario=request.user)
        serializer = RegistroActividadSerializer(registros, many=True)
        return Response(serializer.data)

    def post(self, request):
        plan = PlanEntrenamiento.objects.filter(
            usuario=request.user, activo=True
        ).last()

        if not plan:
            return Response(
                {'error': 'No tienes un plan activo para registrar actividad.'},
                status=status.HTTP_404_NOT_FOUND
            )

        registro = RegistroActividad.objects.create(
            usuario=request.user,
            plan=plan,
            sesion_numero=plan.sesiones_completadas + 1,
            notas=request.data.get('notas', '')
        )

        return Response(
            RegistroActividadSerializer(registro).data,
            status=status.HTTP_201_CREATED
        )


# ─── Progreso de alimentación ─────────────────────────────────

class ProgresoAlimentacionAPIView(APIView):
    """
    GET  /api/progreso/alimentacion/  → historial completo de cumplimiento diario
    POST /api/progreso/alimentacion/  → registrar cumplimiento del dia

    El POST asocia automaticamente al plan activo, actualiza dias_completados,
    y si llega a duracion_dias lo marca como completado.
    Tambien actualiza el RegistroAcceso del dia para reflejar el cumplimiento.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        registros = ProgresoAlimentacion.objects.filter(usuario=request.user)
        serializer = ProgresoAlimentacionSerializer(registros, many=True)
        return Response(serializer.data)

    def post(self, request):
        from django.utils import timezone

        hoy = date.today()

        if ProgresoAlimentacion.objects.filter(
            usuario=request.user, fecha=hoy
        ).exists():
            return Response(
                {'error': 'Ya registraste tu alimentacion de hoy. Usa PUT /api/progreso/alimentacion/<id>/ para editarlo.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        plan_activo = PlanAlimentacion.objects.filter(
            usuario=request.user, activo=True
        ).last()

        serializer = ProgresoAlimentacionSerializer(data=request.data)
        if serializer.is_valid():
            registro = serializer.save(usuario=request.user, plan=plan_activo)

            # Actualizar RegistroAcceso del dia para el calendario
            registro_acceso, _ = RegistroAcceso.objects.get_or_create(
                usuario=request.user, fecha=hoy
            )
            registro_acceso.cumplio_alimentacion = True
            registro_acceso.nivel_alimentacion = registro.nivel_cumplimiento or ''
            registro_acceso.save(update_fields=['cumplio_alimentacion', 'nivel_alimentacion'])

            plan_completado = False
            puede_generar_nuevo = False
            dias_completados = 0
            duracion_dias = 0
            dias_restantes = 0
            porcentaje = 0.0
            mensaje = 'Cumplimiento del dia registrado correctamente.'

            if plan_activo:
                plan_activo.dias_completados = ProgresoAlimentacion.objects.filter(
                    usuario=request.user, plan=plan_activo
                ).count()
                dias_completados = plan_activo.dias_completados
                duracion_dias = plan_activo.duracion_dias
                dias_restantes = max(0, duracion_dias - dias_completados)
                porcentaje = round(
                    (dias_completados / duracion_dias * 100) if duracion_dias > 0 else 0, 1
                )

                if plan_activo.dias_completados >= plan_activo.duracion_dias:
                    plan_activo.completado = True
                    plan_activo.activo = False
                    plan_activo.fecha_completado = timezone.now()
                    plan_completado = True
                    puede_generar_nuevo = True
                    dias_restantes = 0
                    porcentaje = 100.0
                    mensaje = (
                        f'Felicitaciones! Completaste los {duracion_dias} dias del plan de alimentacion. '
                        'Ya puedes generar un nuevo plan desde /api/ia/plan/alimentacion/'
                    )
                else:
                    mensaje = (
                        f'Dia {dias_completados} de {duracion_dias} registrado. '
                        f'Te faltan {dias_restantes} dias para completar el plan.'
                    )

                plan_activo.save()

            return Response({
                'registro': serializer.data,
                'mensaje': mensaje,
                'plan_completado': plan_completado,
                'plan_activo': not plan_completado,
                'puede_generar_nuevo': puede_generar_nuevo,
                'dias_completados': dias_completados,
                'duracion_dias': duracion_dias,
                'dias_restantes': dias_restantes,
                'porcentaje_completado': porcentaje,
            }, status=status.HTTP_201_CREATED)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ProgresoAlimentacionDetalleAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, usuario):
        try:
            return ProgresoAlimentacion.objects.get(pk=pk, usuario=usuario)
        except ProgresoAlimentacion.DoesNotExist:
            return None

    def get(self, request, pk):
        registro = self.get_object(pk, request.user)
        if not registro:
            return Response(
                {'error': 'Registro no encontrado.'},
                status=status.HTTP_404_NOT_FOUND
            )
        return Response(ProgresoAlimentacionSerializer(registro).data)

    def put(self, request, pk):
        registro = self.get_object(pk, request.user)
        if not registro:
            return Response(
                {'error': 'Registro no encontrado.'},
                status=status.HTTP_404_NOT_FOUND
            )
        serializer = ProgresoAlimentacionSerializer(registro, data=request.data, partial=True)
        if serializer.is_valid():
            registro_actualizado = serializer.save()

            # Sincronizar nivel en RegistroAcceso si cambió
            try:
                ra = RegistroAcceso.objects.get(usuario=request.user, fecha=registro.fecha)
                ra.nivel_alimentacion = registro_actualizado.nivel_cumplimiento or ''
                ra.save(update_fields=['nivel_alimentacion'])
            except RegistroAcceso.DoesNotExist:
                pass

            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        registro = self.get_object(pk, request.user)
        if not registro:
            return Response(
                {'error': 'Registro no encontrado.'},
                status=status.HTTP_404_NOT_FOUND
            )
        registro.delete()
        return Response({'mensaje': 'Registro eliminado correctamente.'}, status=status.HTTP_200_OK)


# ─── Sesión de entrenamiento en tiempo real ───────────────────

class IniciarSesionAPIView(APIView):
    """
    POST /api/sesion/iniciar/
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        plan = PlanEntrenamiento.objects.filter(
            usuario=request.user, activo=True
        ).last()

        if not plan:
            plan_completado = PlanEntrenamiento.objects.filter(
                usuario=request.user, completado=True
            ).last()
            if plan_completado:
                return Response(
                    {
                        'error': 'Completaste tu plan anterior! Genera uno nuevo desde /api/ia/plan/entrenamiento/',
                        'plan_completado': True,
                        'puede_generar_nuevo': True,
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )
            return Response(
                {'error': 'No tienes un plan activo. Genera uno desde /api/ia/plan/entrenamiento/'},
                status=status.HTTP_404_NOT_FOUND
            )

        sesion_abierta = SesionEntrenamiento.objects.filter(
            usuario=request.user,
            plan=plan,
            completada=False
        ).last()

        if sesion_abierta:
            return Response({
                'mensaje': 'Retomando sesion en curso.',
                'sesion': SesionEntrenamientoSerializer(sesion_abierta).data,
                'es_sesion_nueva': False,
            }, status=status.HTTP_200_OK)

        # ── Verificar si ya completó una sesión HOY ────────────
        # Evita que el usuario haga dos sesiones el mismo día
        sesion_hoy = SesionEntrenamiento.objects.filter(
            usuario=request.user,
            plan=plan,
            completada=True,
            fecha_inicio__date=date.today()
        ).exists()

        if sesion_hoy:
            dias_semana = request.user.dias_entrenamiento or 3
            sesiones_totales = plan.duracion * dias_semana
            return Response({
                'mensaje': 'Ya completaste tu sesión de hoy. ¡Excelente trabajo! Vuelve mañana para continuar.',
                'sesion_completada_hoy': True,
                'puede_entrenar_hoy': False,
                'sesiones_completadas': plan.sesiones_completadas,
                'sesiones_totales': sesiones_totales,
                'sesiones_restantes': max(0, sesiones_totales - plan.sesiones_completadas),
            }, status=status.HTTP_200_OK)

        dias_semana = request.user.dias_entrenamiento or 3
        sesiones_totales = plan.duracion * dias_semana
        sesion_numero = plan.sesiones_completadas + 1

        sesion = SesionEntrenamiento.objects.create(
            usuario=request.user,
            plan=plan,
        )

        # ── Rotación de ejercicios por grupo muscular ──────────
        # En lugar de repetir siempre los mismos ejercicios,
        # agrupamos por músculo y en cada sesión rotamos el grupo.
        # Ejemplo: sesión 1 → pecho/tríceps, sesión 2 → espalda/bíceps, etc.
        todos_ejercicios = list(plan.rutina_ejercicios.all())

        # Agrupar ejercicios por grupo muscular
        grupos = {}
        for ej in todos_ejercicios:
            grupo = ej.grupo_muscular.lower()
            if grupo not in grupos:
                grupos[grupo] = []
            grupos[grupo].append(ej)

        nombres_grupos = list(grupos.keys())

        if len(nombres_grupos) > 1:
            # Rotar: según el número de sesión decidimos qué grupos trabajar hoy
            # Si hay 4 grupos y es sesión 3 → índice 2 → tercer grupo
            indice = (plan.sesiones_completadas) % len(nombres_grupos)
            grupo_hoy = nombres_grupos[indice]
            ejercicios_hoy = grupos[grupo_hoy]

            # Si el grupo tiene pocos ejercicios, añadir el siguiente grupo también
            if len(ejercicios_hoy) < 3 and len(nombres_grupos) > 1:
                indice_siguiente = (indice + 1) % len(nombres_grupos)
                ejercicios_hoy = ejercicios_hoy + grupos[nombres_grupos[indice_siguiente]]
        else:
            # Solo hay un grupo muscular — usar todos
            ejercicios_hoy = todos_ejercicios

        for ejercicio in ejercicios_hoy:
            EjercicioSesion.objects.create(
                sesion=sesion,
                rutina_ejercicio=ejercicio,
            )

        return Response({
            'mensaje': f'Sesion {sesion_numero} iniciada! A entrenar.',
            'sesion': SesionEntrenamientoSerializer(sesion).data,
            'es_sesion_nueva': True,
            'sesion_numero': sesion_numero,
            'sesiones_totales': sesiones_totales,
            'sesiones_completadas': plan.sesiones_completadas,
        }, status=status.HTTP_201_CREATED)


class CompletarEjercicioAPIView(APIView):
    """
    POST /api/sesion/<sesion_id>/ejercicio/<ejercicio_sesion_id>/completar/
    Marca un ejercicio como completado. Cuando se completa el último,
    cierra la sesión, actualiza el plan y actualiza el RegistroAcceso del día.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, sesion_id, ejercicio_sesion_id):
        from django.utils import timezone

        try:
            sesion = SesionEntrenamiento.objects.get(
                pk=sesion_id, usuario=request.user
            )
        except SesionEntrenamiento.DoesNotExist:
            return Response(
                {'error': 'Sesion no encontrada.'},
                status=status.HTTP_404_NOT_FOUND
            )

        if sesion.completada:
            return Response(
                {'error': 'Esta sesion ya fue completada.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            ejercicio_sesion = EjercicioSesion.objects.get(
                pk=ejercicio_sesion_id, sesion=sesion
            )
        except EjercicioSesion.DoesNotExist:
            return Response(
                {'error': 'Ejercicio no encontrado en esta sesion.'},
                status=status.HTTP_404_NOT_FOUND
            )

        ejercicio_sesion.completado = True
        ejercicio_sesion.fecha_completado = timezone.now()
        ejercicio_sesion.notas = request.data.get('notas', '')
        ejercicio_sesion.save()

        siguiente = sesion.ejercicios_completados.filter(
            completado=False
        ).order_by('rutina_ejercicio__orden').first()

        if siguiente:
            sesion.ejercicio_actual = siguiente.rutina_ejercicio.orden
            sesion.save()

            return Response({
                'mensaje': f'Ejercicio completado. Siguiente: {siguiente.rutina_ejercicio.nombre}',
                'sesion_completada': False,
                'siguiente_ejercicio': EjercicioSesionSerializer(siguiente).data,
                'descanso_segundos': _parsear_descanso(siguiente.rutina_ejercicio.descanso),
                'ejercicios_hechos': sesion.ejercicios_completados.filter(completado=True).count(),
                'total_ejercicios': sesion.ejercicios_completados.count(),
            }, status=status.HTTP_200_OK)

        else:
            sesion.completada = True
            sesion.fecha_fin = timezone.now()
            sesion.save()

            plan = sesion.plan
            dias_semana = request.user.dias_entrenamiento or 3
            sesiones_totales = plan.duracion * dias_semana
            plan.sesiones_completadas += 1

            # Actualizar RegistroAcceso del día — marcar que entrenó
            hoy = date.today()
            registro_acceso, _ = RegistroAcceso.objects.get_or_create(
                usuario=request.user, fecha=hoy
            )
            registro_acceso.entreno = True
            registro_acceso.save(update_fields=['entreno'])

            if plan.sesiones_completadas >= sesiones_totales:
                plan.completado = True
                plan.activo = False
                plan.fecha_completado = timezone.now()
                plan.save()

                RegistroActividad.objects.create(
                    usuario=request.user,
                    plan=plan,
                    sesion_numero=plan.sesiones_completadas,
                    notas=request.data.get('notas', '')
                )

                return Response({
                    'mensaje': (
                        f'Completaste todos los ejercicios! '
                        f'Felicitaciones! Terminaste el plan de {plan.duracion} semanas. '
                        'Ya puedes generar un nuevo plan desde /api/ia/plan/entrenamiento/'
                    ),
                    'sesion_completada': True,
                    'plan_completado': True,
                    'plan_activo': False,
                    'puede_generar_nuevo': True,
                    'sesiones_completadas': plan.sesiones_completadas,
                    'sesiones_totales': sesiones_totales,
                    'porcentaje_completado': 100.0,
                }, status=status.HTTP_200_OK)

            else:
                restantes = sesiones_totales - plan.sesiones_completadas
                plan.save()

                RegistroActividad.objects.create(
                    usuario=request.user,
                    plan=plan,
                    sesion_numero=plan.sesiones_completadas,
                    notas=request.data.get('notas', '')
                )

                return Response({
                    'mensaje': (
                        f'Completaste todos los ejercicios de hoy! '
                        f'Llevas {plan.sesiones_completadas} de {sesiones_totales} sesiones. '
                        f'Te faltan {restantes}. Vuelve manana para tu proxima sesion.'
                    ),
                    'sesion_completada': True,
                    'plan_completado': False,
                    'plan_activo': True,
                    'puede_generar_nuevo': False,
                    'sesiones_completadas': plan.sesiones_completadas,
                    'sesiones_totales': sesiones_totales,
                    'sesiones_restantes': restantes,
                    'porcentaje_completado': round(
                        plan.sesiones_completadas / sesiones_totales * 100, 1
                    ),
                }, status=status.HTTP_200_OK)


class SesionActivaAPIView(APIView):
    """
    GET /api/sesion/activa/
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        sesion = SesionEntrenamiento.objects.filter(
            usuario=request.user,
            completada=False
        ).last()

        plan_activo = PlanEntrenamiento.objects.filter(
            usuario=request.user, activo=True
        ).last()

        estado_plan = None
        if plan_activo:
            dias_semana = request.user.dias_entrenamiento or 3
            sesiones_totales = plan_activo.duracion * dias_semana
            estado_plan = {
                'id': plan_activo.pk,
                'sesiones_completadas': plan_activo.sesiones_completadas,
                'sesiones_totales': sesiones_totales,
                'sesiones_restantes': max(0, sesiones_totales - plan_activo.sesiones_completadas),
                'porcentaje_completado': round(
                    (plan_activo.sesiones_completadas / sesiones_totales * 100)
                    if sesiones_totales > 0 else 0, 1
                ),
                'plan_completado': plan_activo.completado,
            }

        if not sesion:
            return Response({
                'tiene_sesion_activa': False,
                'mensaje': 'No tienes una sesion en curso.',
                'estado_plan': estado_plan,
            })

        return Response({
            'tiene_sesion_activa': True,
            'sesion': SesionEntrenamientoSerializer(sesion).data,
            'estado_plan': estado_plan,
        })


# ─── PROGRESO COMPLETO Y CALENDARIO ──────────────────────────

class RegistrarAccesoAPIView(APIView):
    """
    POST /api/acceso/
    Llamar cada vez que el usuario abre la app.
    - Crea o recupera el RegistroAcceso del día
    - Actualiza la racha del usuario (idempotente: no hace nada si ya se llamó hoy)
    - Devuelve el estado completo del día para que Flutter decida qué mostrar
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        hoy = date.today()
        usuario = request.user

        es_nuevo_acceso = usuario.registrar_acceso_hoy()

        registro_acceso, _ = RegistroAcceso.objects.get_or_create(
            usuario=usuario,
            fecha=hoy
        )

        sesion_hoy = usuario.sesiones.filter(
            fecha_inicio__date=hoy,
            completada=True
        ).exists()

        alim_hoy = usuario.progreso_alimentacion.filter(fecha=hoy).first()

        # ── Recalcular racha desde RegistroAcceso por si está desincronizada ──
        # Corrige perfiles donde la racha muestra 0 aunque hayan tenido actividad
        racha_actual, racha_maxima = _recalcular_racha(usuario)
        if racha_actual != usuario.racha_actual or racha_maxima != usuario.racha_maxima:
            usuario.racha_actual = racha_actual
            usuario.racha_maxima = racha_maxima
            usuario.save(update_fields=['racha_actual', 'racha_maxima'])

        return Response({
            'es_nuevo_acceso': es_nuevo_acceso,
            'fecha': hoy,
            'racha_actual': usuario.racha_actual,
            'racha_maxima': usuario.racha_maxima,
            'entreno_hoy': sesion_hoy,
            'registro_alim_hoy': alim_hoy.nivel_cumplimiento if alim_hoy else None,
            'cumplio_alimentacion_hoy': alim_hoy is not None,
        })


class CalendarioProgresoAPIView(APIView):
    """
    GET /api/progreso/calendario/                       → mes actual
    GET /api/progreso/calendario/?año=2025&mes=3        → mes específico

    Devuelve el mapa de actividad del mes: cada día tiene
    abrio_app / entreno / cumplio_alimentacion / nivel_alimentacion.
    Incluye estadísticas del mes y racha actual.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        hoy = date.today()
        try:
            anio = int(request.query_params.get('año', hoy.year))
            mes = int(request.query_params.get('mes', hoy.month))
            if not (1 <= mes <= 12) or not (2020 <= anio <= 2100):
                raise ValueError
        except (ValueError, TypeError):
            return Response(
                {'error': 'Parámetros año y mes inválidos.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        primer_dia = date(anio, mes, 1)
        ultimo_dia = date(anio, mes, calendar.monthrange(anio, mes)[1])

        # Registros de acceso del mes indexados por fecha
        accesos = {
            r.fecha: r
            for r in RegistroAcceso.objects.filter(
                usuario=request.user,
                fecha__range=(primer_dia, ultimo_dia)
            )
        }

        # Fechas con sesión completada en el mes
        sesiones_mes = set(
            SesionEntrenamiento.objects.filter(
                usuario=request.user,
                completada=True,
                fecha_inicio__date__range=(primer_dia, ultimo_dia)
            ).values_list('fecha_inicio__date', flat=True)
        )

        # Cumplimiento de alimentación del mes indexado por fecha
        alim_mes = {
            p.fecha: p.nivel_cumplimiento
            for p in request.user.progreso_alimentacion.filter(
                fecha__range=(primer_dia, ultimo_dia)
            )
        }

        dias = []
        dia_actual = primer_dia
        while dia_actual <= ultimo_dia:
            acceso = accesos.get(dia_actual)
            entreno = dia_actual in sesiones_mes
            nivel_alim = alim_mes.get(dia_actual, '')

            # Sincronizar RegistroAcceso si hay actividad no registrada aún
            if acceso and (entreno != acceso.entreno or bool(nivel_alim) != acceso.cumplio_alimentacion):
                acceso.entreno = entreno
                acceso.cumplio_alimentacion = bool(nivel_alim)
                acceso.nivel_alimentacion = nivel_alim
                acceso.save(update_fields=['entreno', 'cumplio_alimentacion', 'nivel_alimentacion'])

            dias.append({
                'fecha': dia_actual.isoformat(),
                'abrio_app': acceso is not None,
                'entreno': entreno,
                'cumplio_alimentacion': bool(nivel_alim),
                'nivel_alimentacion': nivel_alim,
                'es_futuro': dia_actual > hoy,
                'es_hoy': dia_actual == hoy,
            })
            dia_actual += timedelta(days=1)

        dias_con_acceso = sum(1 for d in dias if d['abrio_app'] and not d['es_futuro'])
        dias_entrenados = sum(1 for d in dias if d['entreno'])
        dias_alim_ok = sum(1 for d in dias if d['cumplio_alimentacion'])
        dias_transcurridos = (min(hoy, ultimo_dia) - primer_dia).days + 1

        return Response({
            'año': anio,
            'mes': mes,
            'dias': dias,
            'estadisticas_mes': {
                'dias_transcurridos': dias_transcurridos,
                'dias_con_acceso': dias_con_acceso,
                'dias_entrenados': dias_entrenados,
                'dias_alim_cumplidos': dias_alim_ok,
                'porcentaje_constancia': round(
                    dias_con_acceso / dias_transcurridos * 100, 1
                ) if dias_transcurridos > 0 else 0,
                'porcentaje_entrenamiento': round(
                    dias_entrenados / dias_transcurridos * 100, 1
                ) if dias_transcurridos > 0 else 0,
                'porcentaje_alimentacion': round(
                    dias_alim_ok / dias_transcurridos * 100, 1
                ) if dias_transcurridos > 0 else 0,
            },
            'racha_actual': request.user.racha_actual,
            'racha_maxima': request.user.racha_maxima,
        })


class ResumenProgresoAPIView(APIView):
    """
    GET /api/progreso/resumen/          → dashboard completo sin IA
    GET /api/progreso/resumen/?ia=true  → igual + análisis de la IA

    Un solo endpoint que Flutter consume para pintar toda la pantalla
    de progreso: racha, planes activos, historial de peso, sesiones
    recientes, cumplimiento de alimentación y análisis IA opcional.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from . import ia_service

        usuario = request.user
        hoy = date.today()
        hace_7_dias = hoy - timedelta(days=7)

        # ── Planes activos ────────────────────────────────────
        plan_entreno = usuario.planes_entrenamiento.filter(activo=True).last()
        plan_alim = usuario.planes_alimentacion.filter(activo=True).last()

        estado_entrenamiento = None
        if plan_entreno:
            dias_semana = usuario.dias_entrenamiento or 3
            sesiones_totales = plan_entreno.duracion * dias_semana
            estado_entrenamiento = {
                'plan_id': plan_entreno.pk,
                'tipo': plan_entreno.tipo_entrenamiento,
                'nivel': plan_entreno.nivel,
                'sesiones_completadas': plan_entreno.sesiones_completadas,
                'sesiones_totales': sesiones_totales,
                'porcentaje': round(
                    plan_entreno.sesiones_completadas / sesiones_totales * 100, 1
                ) if sesiones_totales else 0,
            }

        estado_alimentacion = None
        if plan_alim:
            estado_alimentacion = {
                'plan_id': plan_alim.pk,
                'calorias': plan_alim.calorias,
                'dias_completados': plan_alim.dias_completados,
                'duracion_dias': plan_alim.duracion_dias,
                'porcentaje': round(
                    plan_alim.dias_completados / plan_alim.duracion_dias * 100, 1
                ) if plan_alim.duracion_dias else 0,
            }

        # ── Historial de peso ─────────────────────────────────
        progresos_peso = list(
            usuario.progresos.values('fecha', 'peso', 'observaciones')[:10]
        )

        # ── Últimas 7 sesiones completadas ────────────────────
        sesiones_recientes = []
        for s in SesionEntrenamiento.objects.filter(
            usuario=usuario,
            completada=True,
            fecha_inicio__date__gte=hace_7_dias
        ).order_by('-fecha_inicio')[:7]:
            total = s.ejercicios_completados.count()
            hechos = s.ejercicios_completados.filter(completado=True).count()
            sesiones_recientes.append({
                'fecha': s.fecha_inicio.date().isoformat(),
                'ejercicios_completados': hechos,
                'ejercicios_totales': total,
                'porcentaje': round(hechos / total * 100, 1) if total else 0,
            })

        # ── Cumplimiento de alimentación últimos 7 días ───────
        alim_reciente = list(
            usuario.progreso_alimentacion.filter(
                fecha__gte=hace_7_dias
            ).values('fecha', 'nivel_cumplimiento', 'calorias_consumidas', 'agua_consumida')[:7]
        )

        # ── Análisis IA (solo si ?ia=true) ────────────────────
        analisis_ia = None
        if request.query_params.get('ia', '').lower() == 'true':
            try:
                analisis_ia = ia_service.analizar_progreso(usuario)
                from .models import Conversacion
                Conversacion.objects.create(
                    usuario=usuario,
                    tipo='seguimiento',
                    mensaje_usuario='Analizar progreso completo',
                    respuesta_ia=str(analisis_ia)
                )
            except Exception as e:
                analisis_ia = {'error': str(e)}

        return Response({
            'racha_actual': usuario.racha_actual,
            'racha_maxima': usuario.racha_maxima,
            'ultimo_acceso': usuario.ultimo_acceso,
            'estado_entrenamiento': estado_entrenamiento,
            'estado_alimentacion': estado_alimentacion,
            'historial_peso': progresos_peso,
            'sesiones_recientes': sesiones_recientes,
            'cumplimiento_alimentacion_reciente': alim_reciente,
            'analisis_ia': analisis_ia,
        })


# ─── Utilidad interna ─────────────────────────────────────────

def _recalcular_racha(usuario):
    from datetime import timedelta as td

    hoy = date.today()
    accesos = list(
        RegistroAcceso.objects.filter(usuario=usuario)
        .order_by('-fecha')
        .values_list('fecha', flat=True)
    )

    # Si no hay accesos previos pero existe el de hoy (recien creado), racha = 1
    if not accesos:
        return 1, max(1, usuario.racha_maxima)

    # Racha actual: contar desde hoy hacia atras
    racha_actual = 0
    racha_maxima = usuario.racha_maxima
    fecha_esperada = hoy

    for fecha in accesos:
        if fecha == fecha_esperada:
            racha_actual += 1
            fecha_esperada = fecha - td(days=1)
        elif fecha < fecha_esperada:
            break

    # Si el acceso mas reciente no es de hoy ni de ayer, racha se rompio
    # pero si hay acceso de hoy garantizamos minimo 1
    if racha_actual == 0 and accesos and accesos[0] == hoy:
        racha_actual = 1

    # Racha maxima: recorrer todos los accesos
    racha_temp = 1
    for i in range(1, len(accesos)):
        if (accesos[i - 1] - accesos[i]).days == 1:
            racha_temp += 1
            if racha_temp > racha_maxima:
                racha_maxima = racha_temp
        else:
            racha_temp = 1

    racha_maxima = max(racha_maxima, racha_actual)
    return racha_actual, racha_maxima


def _parsear_descanso(descanso_str):
    """
    Convierte el texto de descanso de la IA a segundos para el timer de Flutter.
    Ejemplos: '60 segundos' -> 60, '2 minutos' -> 120, '90 seg' -> 90
    """
    import re
    texto = descanso_str.lower()
    numeros = re.findall(r'\d+', texto)
    if not numeros:
        return 60
    valor = int(numeros[0])
    if 'min' in texto:
        return valor * 60



# ─── Avatares predeterminados ─────────────────────────────────

class AvatarListAPIView(APIView):
    """
    GET /api/avatares/
    Devuelve la lista de avatares disponibles para que Flutter los muestre.
    El usuario elige uno y lo guarda con PUT /api/perfil/ -> {avatar: 'avatar_1'}
    """
    permission_classes = [IsAuthenticated]

    AVATARES = [
        {
            'id': 'avatar_1',
            'nombre': 'Corredor',
            'descripcion': 'Para los amantes del cardio y las carreras',
            'emoji': '🏃',
        },
        {
            'id': 'avatar_2',
            'nombre': 'Levantador',
            'descripcion': 'Para los que van al gimnasio a levantar pesas',
            'emoji': '🏋️',
        },
        {
            'id': 'avatar_3',
            'nombre': 'Yogui',
            'descripcion': 'Para los amantes del yoga y la flexibilidad',
            'emoji': '🧘',
        },
        {
            'id': 'avatar_4',
            'nombre': 'Ciclista',
            'descripcion': 'Para los que disfrutan el ciclismo',
            'emoji': '🚴',
        },
        {
            'id': 'avatar_5',
            'nombre': 'Nadador',
            'descripcion': 'Para los que entrenan en la piscina',
            'emoji': '🏊',
        },
        {
            'id': 'avatar_6',
            'nombre': 'Boxeador',
            'descripcion': 'Para los que entrenan artes marciales o boxeo',
            'emoji': '🥊',
        },
        {
            'id': 'avatar_7',
            'nombre': 'Escalador',
            'descripcion': 'Para los amantes de la escalada y el outdoor',
            'emoji': '🧗',
        },
        {
            'id': 'avatar_8',
            'nombre': 'Bailarín',
            'descripcion': 'Para los que entrenan con baile o zumba',
            'emoji': '💃',
        },
    ]

    def get(self, request):
        avatar_actual = request.user.avatar or 'avatar_1'
        avatares = []
        for av in self.AVATARES:
            avatares.append({
                **av,
                'seleccionado': av['id'] == avatar_actual,
            })
        return Response({
            'avatar_actual': avatar_actual,
            'avatares': avatares,
        })


# ─── Logout con blacklist JWT ─────────────────────────────────

class LogoutAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data.get('refresh')
            if not refresh_token:
                return Response(
                    {'error': 'Se requiere el refresh token.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            token = RefreshToken(refresh_token)
            token.blacklist()
            return Response(
                {'mensaje': 'Sesión cerrada correctamente.'},
                status=status.HTTP_200_OK
            )
        except Exception as e:
            return Response(
                {'error': 'Token inválido o ya fue invalidado.'},
                status=status.HTTP_400_BAD_REQUEST
            )


# ─── Rate limiting — throttle personalizado para login ────────

from rest_framework.throttling import AnonRateThrottle

class LoginRateThrottle(AnonRateThrottle):
    rate = '5/minute'
    scope = 'login'


class LoginAPIView(APIView):
    """
    Login con rate limiting — máximo 5 intentos por minuto por IP.
    Reemplaza a TokenObtainPairView en api_urls.py.
    Acepta email + password y devuelve access + refresh tokens.
    """
    permission_classes = [AllowAny]
    throttle_classes = [LoginRateThrottle]

    def post(self, request):
        from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
        from rest_framework_simplejwt.exceptions import TokenError, InvalidToken

        serializer = TokenObtainPairSerializer(data=request.data)
        try:
            serializer.is_valid(raise_exception=True)
        except TokenError as e:
            raise InvalidToken(e.args[0])
        except Exception:
            return Response(
                {'error': 'Correo o contraseña incorrectos.'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        return Response(serializer.validated_data, status=status.HTTP_200_OK)