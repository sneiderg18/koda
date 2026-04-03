from django.db import models
from django.contrib.auth.models import AbstractUser


class Usuario(AbstractUser):
    # ─── Campos existentes ────────────────────────────────────
    edad = models.PositiveIntegerField(null=True, blank=True)
    peso = models.FloatField(null=True, blank=True, help_text="Peso en kg")
    altura = models.FloatField(null=True, blank=True, help_text="Altura en cm")
    email = models.EmailField(unique=True)

    # ─── Objetivo (mejorado) ──────────────────────────────────
    objetivo = models.CharField(max_length=100, blank=True, choices=[
        ('bajar_peso', 'Bajar de peso'),
        ('aumentar_masa', 'Aumentar masa muscular'),
        ('mantenerse', 'Mantenerse'),
        ('mejorar_resistencia', 'Mejorar resistencia'),
        ('rehabilitacion', 'Rehabilitación'),
    ])
    objetivo_tiempo = models.CharField(max_length=200, blank=True,
        help_text="Ej: bajar 5kg en 3 meses")
    motivacion = models.CharField(max_length=50, blank=True, choices=[
        ('salud', 'Salud'),
        ('estetica', 'Estética'),
        ('rendimiento', 'Rendimiento deportivo'),
    ])

    # ─── Datos físicos adicionales ────────────────────────────
    genero = models.CharField(max_length=20, blank=True, choices=[
        ('masculino', 'Masculino'),
        ('femenino', 'Femenino'),
        ('otro', 'Otro'),
        ('prefiero_no_decir', 'Prefiero no decir'),
    ])

    # ─── Nivel de actividad ───────────────────────────────────
    nivel_actividad = models.CharField(max_length=20, blank=True, choices=[
        ('sedentario', 'Sedentario'),
        ('principiante', 'Principiante'),
        ('intermedio', 'Intermedio'),
        ('avanzado', 'Avanzado'),
    ])
    dias_entrenamiento = models.PositiveIntegerField(null=True, blank=True,
        help_text="Días por semana")
    tiempo_sesion = models.PositiveIntegerField(null=True, blank=True,
        help_text="Minutos por sesión")
    lugar_entrenamiento = models.CharField(max_length=20, blank=True, choices=[
        ('casa', 'Casa'),
        ('gimnasio', 'Gimnasio'),
        ('ambos', 'Ambos'),
    ])
    tiene_equipo = models.BooleanField(default=False)

    # ─── Información médica ───────────────────────────────────
    condiciones_medicas = models.TextField(blank=True,
        help_text="Ej: diabetes, hipertensión")
    alergias = models.TextField(blank=True,
        help_text="Alergias alimentarias")
    lesiones = models.TextField(blank=True,
        help_text="Lesiones o limitaciones físicas")
    restricciones_alimentarias = models.CharField(max_length=50, blank=True, choices=[
        ('ninguna', 'Ninguna'),
        ('vegetariano', 'Vegetariano'),
        ('vegano', 'Vegano'),
        ('sin_gluten', 'Sin gluten'),
        ('sin_lactosa', 'Sin lactosa'),
        ('otro', 'Otro'),
    ])

    # ─── Hábitos ─────────────────────────────────────────────
    comidas_por_dia = models.PositiveIntegerField(null=True, blank=True)
    agua_por_dia = models.FloatField(null=True, blank=True,
        help_text="Litros de agua al día")
    calidad_sueno = models.CharField(max_length=20, blank=True, choices=[
        ('bueno', 'Bueno'),
        ('regular', 'Regular'),
        ('malo', 'Malo'),
    ])
    nivel_estres = models.CharField(max_length=20, blank=True, choices=[
        ('bajo', 'Bajo'),
        ('medio', 'Medio'),
        ('alto', 'Alto'),
    ])

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    class Meta:
        verbose_name = 'Usuario'
        verbose_name_plural = 'Usuarios'

    def __str__(self):
        return self.email


class PlanEntrenamiento(models.Model):
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='planes_entrenamiento')
    tipo_entrenamiento = models.CharField(max_length=100, null=True, blank=True)
    nivel = models.CharField(max_length=50)
    duracion = models.IntegerField(help_text="Duracion en semanas")

    def __str__(self):
        return f"Plan {self.pk} - {self.usuario.email}"


class Ejercicio(models.Model):
    nombre = models.CharField(max_length=100)
    grupo_muscular = models.CharField(max_length=100)
    descripcion = models.TextField()
    video_url = models.URLField(blank=True, null=True)

    def __str__(self):
        return self.nombre


class PlanAlimentacion(models.Model):
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='planes_alimentacion')
    calorias = models.IntegerField()
    objetivo = models.CharField(max_length=500)
    creado_en = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Plan Alimentacion - {self.usuario.email}"


class Comida(models.Model):
    nombre = models.CharField(max_length=100)
    calorias = models.IntegerField()
    proteinas = models.FloatField()
    carbohidratos = models.FloatField()
    grasas = models.FloatField()

    def __str__(self):
        return self.nombre


class Progreso(models.Model):
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='progresos')
    peso = models.FloatField(help_text="Peso en kg")
    fecha = models.DateField()
    observaciones = models.TextField(blank=True)

    class Meta:
        ordering = ['-fecha']

    def __str__(self):
        return f"{self.usuario.email} - {self.fecha}"


class Conversacion(models.Model):
    TIPO_CHOICES = [
        ('plan_entrenamiento', 'Plan de entrenamiento'),
        ('plan_alimentacion', 'Plan de alimentación'),
        ('coach', 'Coach personal'),
        ('seguimiento', 'Seguimiento de progreso'),
    ]

    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='conversaciones')
    tipo = models.CharField(max_length=50, choices=TIPO_CHOICES, default='coach')
    mensaje_usuario = models.TextField()
    respuesta_ia = models.TextField()
    fecha = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-fecha']

    def __str__(self):
        return f"{self.usuario.email} - {self.tipo} - {self.fecha}"