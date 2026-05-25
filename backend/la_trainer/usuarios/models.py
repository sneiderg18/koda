from django.db import models
from django.contrib.auth.models import AbstractUser


class Usuario(AbstractUser):
    # ─── Campos existentes ────────────────────────────────────
    # El username es solo nombre para mostrar, puede repetirse.
    # El identificador único real es el email.
    username = models.CharField(max_length=150)
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

    # ─── Racha de constancia ─────────────────────────────────
    racha_actual = models.PositiveIntegerField(default=0,
        help_text="Días consecutivos activos en la app")
    racha_maxima = models.PositiveIntegerField(default=0,
        help_text="Mejor racha histórica")
    ultimo_acceso = models.DateField(null=True, blank=True,
        help_text="Último día que el usuario abrió la app")


    # ─── Términos y condiciones ───────────────────────────────
    acepto_terminos = models.BooleanField(default=False,
        help_text="El usuario aceptó los términos y condiciones al registrarse")
    fecha_acepto_terminos = models.DateTimeField(null=True, blank=True,
        help_text="Fecha en que aceptó los términos")

    # ─── Avatar predeterminado ────────────────────────────────
    AVATARES = [
        ('avatar_1', 'Avatar 1 — Corredor'),
        ('avatar_2', 'Avatar 2 — Levantador'),
        ('avatar_3', 'Avatar 3 — Yogui'),
        ('avatar_4', 'Avatar 4 — Ciclista'),
        ('avatar_5', 'Avatar 5 — Nadador'),
        ('avatar_6', 'Avatar 6 — Boxeador'),
        ('avatar_7', 'Avatar 7 — Escalador'),
        ('avatar_8', 'Avatar 8 — Bailarín'),
    ]
    avatar = models.CharField(max_length=20, blank=True, default='avatar_1',
        choices=AVATARES, help_text="Avatar predeterminado seleccionado por el usuario")

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    class Meta:
        verbose_name = 'Usuario'
        verbose_name_plural = 'Usuarios'

    def __str__(self):
        return self.email

    def registrar_acceso_hoy(self):
        """
        Llama este método cada vez que el usuario abre la app.
        Actualiza la racha y registra el acceso del día.
        Retorna True si es la primera vez hoy, False si ya se registró.
        """
        from datetime import date, timedelta

        hoy = date.today()

        # Ya se registró hoy — no hacer nada
        if self.ultimo_acceso == hoy:
            return False

        ayer = hoy - timedelta(days=1)

        if self.ultimo_acceso == ayer:
            # Día consecutivo — incrementar racha
            self.racha_actual += 1
        else:
            # Se rompió la racha — reiniciar
            self.racha_actual = 1

        # Actualizar racha máxima si corresponde
        if self.racha_actual > self.racha_maxima:
            self.racha_maxima = self.racha_actual

        self.ultimo_acceso = hoy
        self.save(update_fields=['racha_actual', 'racha_maxima', 'ultimo_acceso'])
        return True


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
    completado = models.BooleanField(default=False)
    fecha_completado = models.DateTimeField(null=True, blank=True)
    duracion_dias = models.PositiveIntegerField(default=30, help_text="Duración del plan en días")
    dias_completados = models.PositiveIntegerField(default=0, help_text="Días con registro de cumplimiento")
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
    imagen_url = models.URLField(blank=True, null=True,
        help_text="URL de imagen o GIF del ejercicio")
    descripcion_ia = models.TextField(blank=True,
        help_text="Descripción y técnica generada por IA")

    class Meta:
        ordering = ['orden']

    def __str__(self):
        return f"{self.nombre} - Plan {self.plan.pk}"


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
    ingredientes = models.TextField(blank=True, help_text="Lista de ingredientes con cantidades")
    preparacion = models.TextField(blank=True, help_text="Pasos para preparar la comida")
    tiempo_preparacion = models.PositiveIntegerField(default=0, help_text="Tiempo en minutos")
    orden = models.PositiveIntegerField(default=1)
    imagen_url = models.URLField(blank=True, null=True,
        help_text="URL de imagen del plato o comida")

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
    """Registra cada ejercicio completado dentro de una sesión."""
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


# ─── Nuevo: registro diario de acceso a la app ────────────────
class RegistroAcceso(models.Model):
    """
    Un registro por día por usuario — se crea automáticamente cuando
    el usuario abre la app. Permite pintar el calendario de constancia
    distinguiendo: abrió la app / entrenó / cumplió alimentación.
    """
    usuario = models.ForeignKey(
        Usuario, on_delete=models.CASCADE, related_name='registros_acceso'
    )
    fecha = models.DateField()

    # Estado del día — se actualiza conforme el usuario actúa
    entreno = models.BooleanField(default=False,
        help_text="Completó al menos una sesión de entrenamiento ese día")
    cumplio_alimentacion = models.BooleanField(default=False,
        help_text="Registró cumplimiento de alimentación ese día")
    nivel_alimentacion = models.CharField(
        max_length=20, blank=True,
        choices=[
            ('excelente', 'Excelente'),
            ('bueno', 'Bueno'),
            ('regular', 'Regular'),
            ('malo', 'Malo'),
        ],
        help_text="Copia del nivel_cumplimiento de ProgresoAlimentacion para acceso rápido"
    )

    class Meta:
        unique_together = ('usuario', 'fecha')
        ordering = ['-fecha']
        verbose_name = 'Registro de Acceso'
        verbose_name_plural = 'Registros de Acceso'

    def __str__(self):
        return f"{self.usuario.email} - {self.fecha}"