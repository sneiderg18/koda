from django.db import models
from django.contrib.auth.models import AbstractUser


class Usuario(AbstractUser):
    edad = models.PositiveIntegerField(null=True, blank=True)
    peso = models.FloatField(null=True, blank=True, help_text="Peso en kg")
    altura = models.FloatField(null=True, blank=True, help_text="Altura en cm")
    objetivo = models.CharField(max_length=100, blank=True)
    email = models.EmailField(unique=True)

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

    objetivo = models.CharField(max_length=100)

    creado_en = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Plan Alimentacion - {self.usuario.email}"
    

class Comida (models.Model):

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