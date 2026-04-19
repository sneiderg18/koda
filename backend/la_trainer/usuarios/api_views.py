from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import (
    Ejercicio, PlanEntrenamiento, PlanAlimentacion, Progreso,
    Comida, RutinaEjercicio, RutinaComida, RegistroActividad,
    ProgresoAlimentacion, SesionEntrenamiento, EjercicioSesion
)
from .serializers import (
    RegistroSerializer, UsuarioSerializer, EjercicioSerializer,
    PlanEntrenamientoSerializer, PlanAlimentacionSerializer,
    ComidaSerializer, ProgresoSerializer, RutinaEjercicioSerializer,
    RutinaComidaSerializer, RegistroActividadSerializer,
    ProgresoAlimentacionSerializer, SesionEntrenamientoSerializer,
    EjercicioSesionSerializer
)


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

        return Response({
            'tiene_plan_activo': True,
            'plan': PlanEntrenamientoSerializer(plan).data,
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


# ─── Alimentación ─────────────────────────────────────────────
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
    permission_classes = [IsAuthenticated]

    def get(self, request):
        plan = PlanAlimentacion.objects.filter(
            usuario=request.user, activo=True
        ).last()

        if not plan:
            return Response({
                'tiene_plan_activo': False,
                'mensaje': 'No tienes un plan de alimentación activo. Genera uno desde /api/ia/plan/alimentacion/',
            })

        return Response({
            'tiene_plan_activo': True,
            'plan': PlanAlimentacionSerializer(plan).data,
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
            return Response({'error': 'Este plan ya está finalizado.'}, status=status.HTTP_400_BAD_REQUEST)
        plan.activo = False
        plan.save()
        return Response({'mensaje': 'Plan de alimentación finalizado. Ya puedes generar uno nuevo.'})

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


# ─── Progreso ─────────────────────────────────────────────────
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


# ─── Onboarding ───────────────────────────────────────────────
class OnboardingAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.peso and request.user.altura:
            return Response(
                {'error': 'El perfil básico ya fue completado. Para hacer cambios habla con el coach.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        serializer = UsuarioSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({
                'mensaje': '¡Perfil básico completado! El coach te hará algunas preguntas más.',
                'usuario': serializer.data
            })
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

# ─── Completar sesión ──────────────────────────────────────────
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
                f'¡Felicitaciones! Completaste el plan de {plan.duracion} semanas. '
                'Ya puedes generar un nuevo plan desde /api/ia/plan/entrenamiento/'
            )
        else:
            restantes = sesiones_totales - plan.sesiones_completadas
            mensaje = (
                f'¡Sesión registrada! Llevas {plan.sesiones_completadas} de {sesiones_totales} sesiones. '
                f'Te faltan {restantes} sesión(es) para completar el plan.'
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
    permission_classes = [IsAuthenticated]

    def get(self, request):
        registros = ProgresoAlimentacion.objects.filter(usuario=request.user)
        serializer = ProgresoAlimentacionSerializer(registros, many=True)
        return Response(serializer.data)

    def post(self, request):
        from datetime import date
        if ProgresoAlimentacion.objects.filter(
            usuario=request.user, fecha=date.today()
        ).exists():
            return Response(
                {'error': 'Ya registraste tu alimentación de hoy. Usa PUT para editarlo.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        serializer = ProgresoAlimentacionSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(usuario=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ProgresoAlimentacionDetalleAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, usuario):
        try:
            return ProgresoAlimentacion.objects.get(pk=pk, usuario=usuario)
        except ProgresoAlimentacion.DoesNotExist:
            return None

    def put(self, request, pk):
        registro = self.get_object(pk, request.user)
        if not registro:
            return Response(
                {'error': 'Registro no encontrado.'},
                status=status.HTTP_404_NOT_FOUND
            )
        serializer = ProgresoAlimentacionSerializer(registro, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
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
    El usuario presiona 'Empezar rutina'. Crea la sesión y
    devuelve todos los ejercicios listos para recorrer uno a uno.
    Si ya hay una sesión activa sin completar la devuelve
    en lugar de crear una nueva.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        plan = PlanEntrenamiento.objects.filter(
            usuario=request.user, activo=True
        ).last()

        if not plan:
            return Response(
                {'error': 'No tienes un plan activo. Genera uno desde /api/ia/plan/entrenamiento/'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Si ya hay una sesión abierta hoy la reutiliza
        sesion_abierta = SesionEntrenamiento.objects.filter(
            usuario=request.user,
            plan=plan,
            completada=False
        ).last()

        if sesion_abierta:
            return Response({
                'mensaje': 'Retomando sesión en curso.',
                'sesion': SesionEntrenamientoSerializer(sesion_abierta).data
            }, status=status.HTTP_200_OK)

        # Crea sesión nueva
        sesion = SesionEntrenamiento.objects.create(
            usuario=request.user,
            plan=plan,
        )

        # Crea un EjercicioSesion por cada ejercicio del plan
        for ejercicio in plan.rutina_ejercicios.all():
            EjercicioSesion.objects.create(
                sesion=sesion,
                rutina_ejercicio=ejercicio,
            )

        return Response({
            'mensaje': '¡Sesión iniciada! A entrenar.',
            'sesion': SesionEntrenamientoSerializer(sesion).data
        }, status=status.HTTP_201_CREATED)


class CompletarEjercicioAPIView(APIView):
    """
    POST /api/sesion/<sesion_id>/ejercicio/<ejercicio_sesion_id>/completar/
    El usuario presiona 'Finalicé este ejercicio'.
    Marca el ejercicio como completado y devuelve el siguiente.
    Si era el último, cierra la sesión y dispara CompletarSesion.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, sesion_id, ejercicio_sesion_id):
        from django.utils import timezone

        # Verificar que la sesión pertenece al usuario
        try:
            sesion = SesionEntrenamiento.objects.get(
                pk=sesion_id, usuario=request.user
            )
        except SesionEntrenamiento.DoesNotExist:
            return Response(
                {'error': 'Sesión no encontrada.'},
                status=status.HTTP_404_NOT_FOUND
            )

        if sesion.completada:
            return Response(
                {'error': 'Esta sesión ya fue completada.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Verificar que el ejercicio pertenece a esta sesión
        try:
            ejercicio_sesion = EjercicioSesion.objects.get(
                pk=ejercicio_sesion_id, sesion=sesion
            )
        except EjercicioSesion.DoesNotExist:
            return Response(
                {'error': 'Ejercicio no encontrado en esta sesión.'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Marcar ejercicio como completado
        ejercicio_sesion.completado = True
        ejercicio_sesion.fecha_completado = timezone.now()
        ejercicio_sesion.notas = request.data.get('notas', '')
        ejercicio_sesion.save()

        # Buscar el siguiente ejercicio pendiente
        siguiente = sesion.ejercicios_completados.filter(
            completado=False
        ).order_by('rutina_ejercicio__orden').first()

        if siguiente:
            # Actualizar ejercicio_actual en la sesión
            sesion.ejercicio_actual = siguiente.rutina_ejercicio.orden
            sesion.save()

            return Response({
                'mensaje': f'Ejercicio completado. Siguiente: {siguiente.rutina_ejercicio.nombre}',
                'sesion_completada': False,
                'siguiente_ejercicio': EjercicioSesionSerializer(siguiente).data,
                'descanso_segundos': _parsear_descanso(siguiente.rutina_ejercicio.descanso),
            }, status=status.HTTP_200_OK)

        else:
            # Era el último — cerrar sesión
            sesion.completada = True
            sesion.fecha_fin = timezone.now()
            sesion.save()

            # Disparar lógica de CompletarSesion
            plan = sesion.plan
            dias_semana = request.user.dias_entrenamiento or 3
            sesiones_totales = plan.duracion * dias_semana
            plan.sesiones_completadas += 1

            if plan.sesiones_completadas >= sesiones_totales:
                plan.completado = True
                plan.activo = False
                plan.fecha_completado = timezone.now()
                mensaje_plan = (
                    f'¡Completaste el plan de {plan.duracion} semanas! '
                    'Ya puedes generar uno nuevo.'
                )
            else:
                restantes = sesiones_totales - plan.sesiones_completadas
                mensaje_plan = (
                    f'Llevas {plan.sesiones_completadas} de {sesiones_totales} sesiones. '
                    f'Te faltan {restantes}.'
                )

            plan.save()

            # Registrar en calendario de actividad
            RegistroActividad.objects.create(
                usuario=request.user,
                plan=plan,
                sesion_numero=plan.sesiones_completadas,
                notas=request.data.get('notas', '')
            )

            return Response({
                'mensaje': '¡Completaste todos los ejercicios de hoy! ' + mensaje_plan,
                'sesion_completada': True,
                'plan_completado': plan.completado,
                'plan_activo': plan.activo,
                'sesiones_completadas': plan.sesiones_completadas,
                'sesiones_totales': sesiones_totales,
            }, status=status.HTTP_200_OK)


class SesionActivaAPIView(APIView):
    """
    GET /api/sesion/activa/
    Flutter consulta esto al volver a la pantalla de rutina
    para saber si hay una sesión en curso y en qué ejercicio está.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        sesion = SesionEntrenamiento.objects.filter(
            usuario=request.user,
            completada=False
        ).last()

        if not sesion:
            return Response({
                'tiene_sesion_activa': False,
                'mensaje': 'No tienes una sesión en curso.'
            })

        return Response({
            'tiene_sesion_activa': True,
            'sesion': SesionEntrenamientoSerializer(sesion).data
        })


def _parsear_descanso(descanso_str):
    """
    Convierte el texto de descanso de la IA a segundos para el timer de Flutter.
    Ejemplos: '60 segundos' → 60, '2 minutos' → 120, '90 seg' → 90
    """
    import re
    texto = descanso_str.lower()
    numeros = re.findall(r'\d+', texto)
    if not numeros:
        return 60  # default
    valor = int(numeros[0])
    if 'min' in texto:
        return valor * 60
    return valor