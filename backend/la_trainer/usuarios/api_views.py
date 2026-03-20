from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Ejercicio, PlanEntrenamiento, PlanAlimentacion, Progreso, Comida
from .serializers import (
    RegistroSerializer, UsuarioSerializer, EjercicioSerializer,
    PlanEntrenamientoSerializer, PlanAlimentacionSerializer,
    ComidaSerializer, ProgresoSerializer
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


class EjercicioListAPIView(generics.ListAPIView):
    queryset = Ejercicio.objects.all()
    serializer_class = EjercicioSerializer
    permission_classes = [IsAuthenticated]


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


class PlanEntrenamientoDetalleAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, usuario):
        try:
            return PlanEntrenamiento.objects.get(pk=pk, usuario=usuario)
        except PlanEntrenamiento.DoesNotExist:
            return None

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


class PlanAlimentacionDetalleAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, usuario):
        try:
            return PlanAlimentacion.objects.get(pk=pk, usuario=usuario)
        except PlanAlimentacion.DoesNotExist:
            return None

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