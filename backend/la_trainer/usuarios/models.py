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
    activo = models.BooleanField(default=True)
    completado = models.BooleanField(default=False)
    fecha_completado = models.DateTimeField(null=True, blank=True)
    sesiones_completadas = models.PositiveIntegerField(default=0)
    creado_en = models.DateTimeField(auto_now_add=True)

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
    activo = models.BooleanField(default=True)
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


class RutinaEjercicio(models.Model):
    plan = models.ForeignKey(
        PlanEntrenamiento,
        on_delete=models.CASCADE,
        related_name='rutina_ejercicios'
    )
    nombre = models.CharField(max_length=100)
    grupo_muscular = models.CharField(max_length=100)
    series = models.PositiveIntegerField()
    repeticiones = models.PositiveIntegerField()
    descanso = models.CharField(max_length=50, help_text="Ej: 60 segundos")
    orden = models.PositiveIntegerField(default=1, help_text="Orden en la rutina")

    class Meta:
        ordering = ['orden']

    def __str__(self):
        return f"{self.nombre} - Plan {self.plan.pk}"


# ─── Igual que RutinaEjercicio pero para alimentación ────────
class RutinaComida(models.Model):
    MOMENTO_CHOICES = [
        ('desayuno', 'Desayuno'),
        ('almuerzo', 'Almuerzo'),
        ('cena', 'Cena'),
        ('merienda', 'Merienda'),
    ]

    plan = models.ForeignKey(
        PlanAlimentacion,
        on_delete=models.CASCADE,
        related_name='rutina_comidas'
    )
    nombre = models.CharField(max_length=200)
    momento = models.CharField(max_length=20, choices=MOMENTO_CHOICES, default='almuerzo')
    calorias = models.IntegerField(default=0)
    proteinas = models.FloatField(default=0)
    carbohidratos = models.FloatField(default=0)
    grasas = models.FloatField(default=0)
    descripcion = models.TextField(blank=True)
    orden = models.PositiveIntegerField(default=1)

    class Meta:
        ordering = ['orden']

    def __str__(self):
        return f"{self.nombre} - Plan {self.plan.pk}"

class RegistroActividad(models.Model):
    """Registra cada sesión completada — sirve como calendario de constancia."""
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='registros_actividad')
    plan = models.ForeignKey(
        PlanEntrenamiento, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='registros_actividad'
    )
    fecha = models.DateField(auto_now_add=True)
    sesion_numero = models.PositiveIntegerField(help_text="Número de sesión dentro del plan")
    notas = models.TextField(blank=True)

    class Meta:
        ordering = ['-fecha']
        verbose_name = 'Registro de Actividad'
        verbose_name_plural = 'Registros de Actividad'

    def __str__(self):
        return f"{self.usuario.email} - Sesión {self.sesion_numero} - {self.fecha}"


class ProgresoAlimentacion(models.Model):
    """Registro diario del cumplimiento del plan de alimentación."""
    NIVEL_CHOICES = [
        ('excelente', 'Excelente'),
        ('bueno', 'Bueno'),
        ('regular', 'Regular'),
        ('malo', 'Malo'),
    ]
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='progreso_alimentacion')
    plan = models.ForeignKey(
        PlanAlimentacion, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='progresos'
    )
    fecha = models.DateField()
    calorias_consumidas = models.PositiveIntegerField(null=True, blank=True)
    nivel_cumplimiento = models.CharField(max_length=20, choices=NIVEL_CHOICES, blank=True)
    agua_consumida = models.FloatField(null=True, blank=True, help_text="Litros consumidos")
    notas = models.TextField(blank=True)

    class Meta:
        ordering = ['-fecha']
        unique_together = ('usuario', 'fecha')
        verbose_name = 'Progreso de Alimentación'
        verbose_name_plural = 'Progresos de Alimentación'

    def __str__(self):
        return f"{self.usuario.email} - Alimentación {self.fecha}"

class SesionEntrenamiento(models.Model):
    """
    Representa una sesión de entrenamiento en tiempo real.
    Se crea cuando el usuario presiona 'Empezar' y se cierra
    cuando completa el último ejercicio.
    """
    usuario = models.ForeignKey(
        Usuario, on_delete=models.CASCADE, related_name='sesiones'
    )
    plan = models.ForeignKey(
        PlanEntrenamiento, on_delete=models.CASCADE, related_name='sesiones'
    )
    fecha_inicio = models.DateTimeField(auto_now_add=True)
    fecha_fin = models.DateTimeField(null=True, blank=True)
    completada = models.BooleanField(default=False)
    ejercicio_actual = models.PositiveIntegerField(
        default=1, help_text="Orden del ejercicio en curso"
    )

    class Meta:
        ordering = ['-fecha_inicio']
        verbose_name = 'Sesión de entrenamiento'
        verbose_name_plural = 'Sesiones de entrenamiento'

    def __str__(self):
        return f"{self.usuario.email} - Sesión {self.pk} - {self.fecha_inicio.date()}"


class EjercicioSesion(models.Model):
    """
    Registra cada ejercicio completado dentro de una sesión.
    """
    sesion = models.ForeignKey(
        SesionEntrenamiento, on_delete=models.CASCADE, related_name='ejercicios_completados'
    )
    rutina_ejercicio = models.ForeignKey(
        RutinaEjercicio, on_delete=models.CASCADE
    )
    completado = models.BooleanField(default=False)
    fecha_completado = models.DateTimeField(null=True, blank=True)
    notas = models.TextField(blank=True)

    class Meta:
        ordering = ['rutina_ejercicio__orden']

    def __str__(self):
        return f"Sesión {self.sesion.pk} - {self.rutina_ejercicio.nombre}"