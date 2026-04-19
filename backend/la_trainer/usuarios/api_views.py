from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import (
    Ejercicio, PlanEntrenamiento, PlanAlimentacion, Progreso,
    Comida, RutinaEjercicio, RutinaComida, RegistroActividad, ProgresoAlimentacion,
    SesionEntrenamiento, EjercicioSesion
)
from .serializers import (
    RegistroSerializer, UsuarioSerializer, EjercicioSerializer,
    PlanEntrenamientoSerializer, PlanAlimentacionSerializer,
    ComidaSerializer, ProgresoSerializer, RutinaEjercicioSerializer,
    RutinaComidaSerializer, RegistroActividadSerializer, ProgresoAlimentacionSerializer,
    SesionEntrenamientoSerializer, EjercicioSesionSerializer
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
    """
    GET /api/planes/alimentacion/activo/

    Devuelve el plan activo con TODAS las comidas del dia (rutina_comidas),
    cada una con nombre, momento, macros, ingredientes, preparacion y
    tiempo de preparacion. Equivalente a PlanActivoAPIView para ejercicios.

    Tambien incluye el progreso del dia actual para que Flutter sepa
    si el usuario ya registro su alimentacion hoy.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from datetime import date

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

        # Verificar si ya registro cumplimiento hoy
        progreso_hoy = ProgresoAlimentacion.objects.filter(
            usuario=request.user, fecha=date.today()
        ).first()

        return Response({
            'tiene_plan_activo': True,
            'plan': PlanAlimentacionSerializer(plan).data,
            # Progreso del plan (igual que ejercicios)
            'dias_completados': plan.dias_completados,
            'duracion_dias': plan.duracion_dias,
            'dias_restantes': max(0, plan.duracion_dias - plan.dias_completados),
            'porcentaje_completado': round(
                (plan.dias_completados / plan.duracion_dias * 100) if plan.duracion_dias > 0 else 0, 1
            ),
            # Estado del dia — Flutter decide si mostrar boton de registro o el check de "ya listo hoy"
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


# ─── Progreso de peso corporal ─────────────────────────────────

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


# ─── Progreso de alimentacion ─────────────────────────────────

class ProgresoAlimentacionAPIView(APIView):
    """
    GET  /api/progreso/alimentacion/  → historial completo de cumplimiento diario
    POST /api/progreso/alimentacion/  → registrar cumplimiento del dia

    El POST es el equivalente a completar un ejercicio en el flujo de entrenamiento:
    - Asocia automaticamente al plan activo
    - Actualiza dias_completados del plan
    - Si llega a duracion_dias lo marca como completado (igual que sesiones en entrenamiento)
    - Devuelve estado completo del plan para que Flutter muestre progreso sin calcular nada
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        registros = ProgresoAlimentacion.objects.filter(usuario=request.user)
        serializer = ProgresoAlimentacionSerializer(registros, many=True)
        return Response(serializer.data)

    def post(self, request):
        from datetime import date
        from django.utils import timezone

        # Un solo registro por dia
        if ProgresoAlimentacion.objects.filter(
            usuario=request.user, fecha=date.today()
        ).exists():
            return Response(
                {'error': 'Ya registraste tu alimentacion de hoy. Usa PUT /api/progreso/alimentacion/<id>/ para editarlo.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Asociar automaticamente al plan de alimentacion activo
        plan_activo = PlanAlimentacion.objects.filter(
            usuario=request.user, activo=True
        ).last()

        serializer = ProgresoAlimentacionSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(usuario=request.user, plan=plan_activo)

            # Calcular estado del plan para devolver en la respuesta
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
                    # Plan completado automaticamente — igual que cuando se completa
                    # la ultima sesion de entrenamiento
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
                # Estado del plan — mismos campos que el flujo de ejercicios
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


# ─── Sesion de entrenamiento en tiempo real ───────────────────

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

        dias_semana = request.user.dias_entrenamiento or 3
        sesiones_totales = plan.duracion * dias_semana
        sesion_numero = plan.sesiones_completadas + 1

        sesion = SesionEntrenamiento.objects.create(
            usuario=request.user,
            plan=plan,
        )

        for ejercicio in plan.rutina_ejercicios.all():
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
    return valor