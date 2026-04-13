from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from .models import Usuario, PlanEntrenamiento, Ejercicio, PlanAlimentacion, Comida, Progreso, Conversacion, RutinaEjercicio

class RegistroSerializer (serializers.ModelSerializer):
    password1 = serializers.CharField(write_only=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True)

    class Meta:
        model = Usuario
        fields = ('email', 'username', 'password1', 'password2')

    def validate(self, data):
        if data['password1'] != data['password2']:
            raise serializers.ValidationError('Las contraseñas no coinciden.')
        return data
    
    def validate_email(self, value):
        if Usuario.objects.filter(email=value.lower()).exists():
            raise serializers.ValidationError('Ya existe una cuenta con este correo.')
        return value.lower()
    
    def create(self, validated_data):
        usuario = Usuario.objects.create_user(
            email=validated_data['email'],
            username=validated_data['username'],
            password=validated_data['password1']
        )
        return usuario
    
class UsuarioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuario
        fields = (
            'id', 'email', 'username',
            # Datos básicos
            'edad', 'peso', 'altura', 'genero',
            # Objetivo
            'objetivo', 'objetivo_tiempo', 'motivacion',
            # Nivel de actividad
            'nivel_actividad', 'dias_entrenamiento', 'tiempo_sesion',
            'lugar_entrenamiento', 'tiene_equipo',
            # Información médica
            'condiciones_medicas', 'alergias', 'lesiones',
            'restricciones_alimentarias',
            # Hábitos
            'comidas_por_dia', 'agua_por_dia', 'calidad_sueno', 'nivel_estres',
            # Fechas
            'date_joined',
        )
        read_only_fields = ('email', 'date_joined')

class EjercicioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ejercicio
        fields = '__all__'

class RutinaEjercicioSerializer(serializers.ModelSerializer):
    class Meta:
        model = RutinaEjercicio
        fields = '__all__'
        read_only_fields = ('plan',)

class PlanEntrenamientoSerializer(serializers.ModelSerializer):
    rutina_ejercicios = RutinaEjercicioSerializer(many=True, read_only=True)

    class Meta:
        model = PlanEntrenamiento
        fields = '__all__'
        read_only_fields = ('usuario',)


class PlanAlimentacionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlanAlimentacion
        fields = '__all__'
        read_only_fields = ('usuario',)


class ComidaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Comida
        fields = '__all__'


class ProgresoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Progreso
        fields = '__all__'
        read_only_fields = ('usuario',)

class ConversacionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Conversacion
        fields = ('id', 'tipo', 'mensaje_usuario', 'respuesta_ia', 'fecha')
        read_only_fields = ('id', 'fecha')