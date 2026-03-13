from django.db import models


# Usuarios
class Usuario(models.Model):
    id_usuario = models.AutoField(primary_key=True)
    nombre = models.CharField(max_length=100)
    email = models.EmailField()
    contraseña = models.CharField(max_length=255)
    edad = models.IntegerField()
    peso = models.FloatField()
    altura = models.FloatField()
    objetivo = models.CharField(max_length=100)

    def __str__(self):
        return self.nombre


# Planes de entrenamiento
class PlanEntrenamiento(models.Model):
    id_plan = models.AutoField(primary_key=True)
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE)
    tipo_entrenamiento = models.CharField(max_length=100, null=True, blank=True)
    nivel = models.CharField(max_length=50)
    duracion = models.IntegerField()

    def __str__(self):
        return f"Plan {self.id_plan} - {self.usuario.nombre}"


# Ejercicios
class Ejercicio(models.Model):
    id_ejercicio = models.AutoField(primary_key=True)
    nombre = models.CharField(max_length=100)
    grupo_muscular = models.CharField(max_length=100)
    descripcion = models.TextField()
    video_url = models.URLField(blank=True, null=True)

    def __str__(self):
        return self.nombre


# Plan de alimentación
class PlanAlimentacion(models.Model):
    id_plan_alimentacion = models.AutoField(primary_key=True)
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE)
    calorias = models.IntegerField()
    objetivo = models.CharField(max_length=100)

    def __str__(self):
        return f"Plan Alimentación {self.usuario.nombre}"


# Comidas
class Comida(models.Model):
    id_comida = models.AutoField(primary_key=True)
    nombre = models.CharField(max_length=100)
    calorias = models.IntegerField()
    proteinas = models.FloatField()
    carbohidratos = models.FloatField()
    grasas = models.FloatField()

    def __str__(self):
        return self.nombre


# Progreso del usuario
class Progreso(models.Model):
    id_progreso = models.AutoField(primary_key=True)
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE)
    peso = models.FloatField()
    fecha = models.DateField()
    observaciones = models.TextField()

    def __str__(self):
        return f"{self.usuario.nombre} - {self.fecha}"