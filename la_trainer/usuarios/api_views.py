from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Ejercicio, PlanEntrenamiento, PlanAlimentacion, Progreso
from .serializers import (
    RegistroSerializer, UsuarioSerializer, EjercicioSerializer, PlanEntrenamientoSerializer, PlanAlimentacionSerializer, ComidaSerializer, ProgresoSerializer
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
    

class EjercicioListAPIView(generics.ListAPIView):
    queryset=Ejercicio.objects.all()
    serializer_class = EjercicioSerializer
    permission_classes = [IsAuthenticated]


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
        return Response (serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    

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
        return Response (serializer.errors, status=status.HTTP_400_BAD_REQUEST)