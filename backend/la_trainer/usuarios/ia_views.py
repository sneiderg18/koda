from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated

from .models import Conversacion, PlanEntrenamiento, PlanAlimentacion, RutinaEjercicio, RutinaComida
from .serializers import (
    PlanEntrenamientoSerializer, PlanAlimentacionSerializer,
    ConversacionSerializer
)
from . import ia_service


class GenerarPlanEntrenamientoAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # Verifica si ya tiene un plan activo
        plan_activo = PlanEntrenamiento.objects.filter(
            usuario=request.user, activo=True
        ).last()
        if plan_activo:
            return Response(
                {
                    'error': 'Ya tienes un plan de entrenamiento activo. Finalízalo antes de generar uno nuevo.',
                    'plan_actual': PlanEntrenamientoSerializer(plan_activo).data
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            resultado = ia_service.generar_plan_entrenamiento(request.user)

            plan = PlanEntrenamiento.objects.create(
                usuario=request.user,
                tipo_entrenamiento=resultado.get('tipo_entrenamiento', ''),
                nivel=resultado.get('nivel', 'Principiante'),
                duracion=resultado.get('duracion', 4),
            )

            # Guarda cada ejercicio de la rutina en DB
            ejercicios = resultado.get('ejercicios', [])
            for index, ejercicio in enumerate(ejercicios):
                RutinaEjercicio.objects.create(
                    plan=plan,
                    nombre=ejercicio.get('nombre', ''),
                    grupo_muscular=ejercicio.get('grupo_muscular', ''),
                    series=ejercicio.get('series', 3),
                    repeticiones=ejercicio.get('repeticiones', 10),
                    descanso=ejercicio.get('descanso', '60 segundos'),
                    orden=index + 1
                )

            Conversacion.objects.create(
                usuario=request.user,
                tipo='plan_entrenamiento',
                mensaje_usuario='Generar plan de entrenamiento',
                respuesta_ia=str(resultado)
            )

            return Response({
                'plan': PlanEntrenamientoSerializer(plan).data,
                'detalle': resultado
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class GenerarPlanAlimentacionAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # Verifica si ya tiene un plan de alimentación activo
        plan_activo = PlanAlimentacion.objects.filter(
            usuario=request.user, activo=True
        ).last()
        if plan_activo:
            return Response(
                {
                    'error': 'Ya tienes un plan de alimentación activo. Finalízalo antes de generar uno nuevo.',
                    'plan_actual': PlanAlimentacionSerializer(plan_activo).data
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            resultado = ia_service.generar_plan_alimentacion(request.user)

            plan = PlanAlimentacion.objects.create(
                usuario=request.user,
                calorias=resultado.get('calorias_diarias', 2000),
                objetivo=resultado.get('objetivo', ''),
            )

            # Guarda cada comida de la rutina en DB
            comidas = resultado.get('comidas', [])
            for index, comida in enumerate(comidas):
                momento = comida.get('momento', 'Almuerzo').lower()
                # Normaliza el momento al choice correcto
                momento_map = {
                    'desayuno': 'desayuno',
                    'almuerzo': 'almuerzo',
                    'cena': 'cena',
                    'merienda': 'merienda',
                    'snack': 'merienda',
                }
                momento_normalizado = momento_map.get(momento, 'merienda')

                RutinaComida.objects.create(
                    plan=plan,
                    nombre=comida.get('nombre', ''),
                    momento=momento_normalizado,
                    calorias=comida.get('calorias', 0),
                    proteinas=comida.get('proteinas', 0),
                    carbohidratos=comida.get('carbohidratos', 0),
                    grasas=comida.get('grasas', 0),
                    descripcion=comida.get('descripcion', ''),
                    orden=index + 1
                )

            Conversacion.objects.create(
                usuario=request.user,
                tipo='plan_alimentacion',
                mensaje_usuario='Generar plan de alimentación',
                respuesta_ia=str(resultado)
            )

            return Response({
                'plan': PlanAlimentacionSerializer(plan).data,
                'detalle': resultado
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AnalizarProgresoAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            resultado = ia_service.analizar_progreso(request.user)
            Conversacion.objects.create(
                usuario=request.user,
                tipo='seguimiento',
                mensaje_usuario='Analizar progreso',
                respuesta_ia=str(resultado)
            )
            return Response(resultado)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ChatCoachAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        mensaje = request.data.get('mensaje', '').strip()
        if not mensaje:
            return Response(
                {'error': 'El mensaje no puede estar vacío.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            respuesta = ia_service.chat_coach(request.user, mensaje)
            Conversacion.objects.create(
                usuario=request.user,
                tipo='coach',
                mensaje_usuario=mensaje,
                respuesta_ia=respuesta
            )
            return Response({'respuesta': respuesta})
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class HistorialConversacionAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        tipo = request.query_params.get('tipo', None)
        conversaciones = request.user.conversaciones.all()
        if tipo:
            conversaciones = conversaciones.filter(tipo=tipo)
        serializer = ConversacionSerializer(conversaciones[:20], many=True)
        return Response(serializer.data)