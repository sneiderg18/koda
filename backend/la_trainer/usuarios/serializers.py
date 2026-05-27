from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from .models import (
    Usuario, PlanEntrenamiento, Ejercicio, PlanAlimentacion,
    Comida, Progreso, Conversacion, RutinaEjercicio, RutinaComida,
    RegistroActividad, ProgresoAlimentacion, SesionEntrenamiento, EjercicioSesion
)


class RegistroSerializer(serializers.ModelSerializer):
    password1 = serializers.CharField(write_only=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True)

    acepto_terminos = serializers.BooleanField(write_only=True)

    class Meta:
        model = Usuario
        fields = ('email', 'username', 'password1', 'password2', 'acepto_terminos')

    def validate(self, data):
        if data['password1'] != data['password2']:
            raise serializers.ValidationError('Las contraseñas no coinciden.')
        if not data.get('acepto_terminos'):
            raise serializers.ValidationError(
                'Debes aceptar los términos y condiciones para registrarte.'
            )
        return data

    def validate_email(self, value):
        if Usuario.objects.filter(email=value.lower()).exists():
            raise serializers.ValidationError('Ya existe una cuenta con este correo.')
        return value.lower()

    def create(self, validated_data):
        from django.utils import timezone
        usuario = Usuario.objects.create_user(
            email=validated_data['email'],
            username=validated_data['username'],
            password=validated_data['password1']
        )
        usuario.acepto_terminos = True
        usuario.fecha_acepto_terminos = timezone.now()
        usuario.save(update_fields=['acepto_terminos', 'fecha_acepto_terminos'])
        return usuario


class UsuarioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuario
        fields = (
            'id', 'email', 'username',
            'edad', 'peso', 'altura', 'genero',
            'objetivo', 'objetivo_tiempo', 'motivacion',
            'nivel_actividad', 'dias_entrenamiento', 'tiempo_sesion',
            'lugar_entrenamiento', 'tiene_equipo',
            'condiciones_medicas', 'alergias', 'lesiones',
            'restricciones_alimentarias',
            'comidas_por_dia', 'agua_por_dia', 'calidad_sueno', 'nivel_estres',
            'avatar', 'acepto_terminos', 'fecha_acepto_terminos',
            'date_joined',
        )
        read_only_fields = ('email', 'date_joined', 'acepto_terminos', 'fecha_acepto_terminos')


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


# ─── Alimentación ─────────────────────────────────────────────
class RutinaComidaSerializer(serializers.ModelSerializer):
    class Meta:
        model = RutinaComida
        fields = '__all__'
        read_only_fields = ('plan',)


class PlanAlimentacionSerializer(serializers.ModelSerializer):
    rutina_comidas = RutinaComidaSerializer(many=True, read_only=True)

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

class RegistroActividadSerializer(serializers.ModelSerializer):
    class Meta:
        model = RegistroActividad
        fields = ('id', 'plan', 'fecha', 'sesion_numero', 'notas')
        read_only_fields = ('id', 'fecha', 'sesion_numero')


class ProgresoAlimentacionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProgresoAlimentacion
        fields = ('id', 'plan', 'fecha', 'calorias_consumidas', 'nivel_cumplimiento', 'agua_consumida', 'notas')
        read_only_fields = ('id',)

class EjercicioSesionSerializer(serializers.ModelSerializer):
    nombre = serializers.CharField(source='rutina_ejercicio.nombre', read_only=True)
    grupo_muscular = serializers.CharField(source='rutina_ejercicio.grupo_muscular', read_only=True)
    series = serializers.IntegerField(source='rutina_ejercicio.series', read_only=True)
    repeticiones = serializers.IntegerField(source='rutina_ejercicio.repeticiones', read_only=True)
    descanso = serializers.CharField(source='rutina_ejercicio.descanso', read_only=True)
    orden = serializers.IntegerField(source='rutina_ejercicio.orden', read_only=True)

    class Meta:
        model = EjercicioSesion
        fields = (
            'id', 'rutina_ejercicio', 'nombre', 'grupo_muscular',
            'series', 'repeticiones', 'descanso', 'orden',
            'completado', 'fecha_completado', 'notas'
        )
        read_only_fields = ('id', 'rutina_ejercicio', 'fecha_completado')


class SesionEntrenamientoSerializer(serializers.ModelSerializer):
    ejercicios_completados = EjercicioSesionSerializer(many=True, read_only=True)
    total_ejercicios = serializers.SerializerMethodField()
    ejercicios_hechos = serializers.SerializerMethodField()

    class Meta:
        model = SesionEntrenamiento
        fields = (
            'id', 'plan', 'fecha_inicio', 'fecha_fin',
            'completada', 'ejercicio_actual',
            'total_ejercicios', 'ejercicios_hechos',
            'ejercicios_completados'
        )
        read_only_fields = ('id', 'fecha_inicio', 'fecha_fin', 'completada')

    def get_total_ejercicios(self, obj):
        return obj.plan.rutina_ejercicios.count()

    def get_ejercicios_hechos(self, obj):
        return obj.ejercicios_completados.filter(completado=True).count()