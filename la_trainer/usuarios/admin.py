from django.contrib import admin
from .models import Usuario, PlanEntrenamiento, Ejercicio, PlanAlimentacion, Comida, Progreso

admin.site.register(Usuario)
admin.site.register(PlanEntrenamiento)
admin.site.register(Ejercicio)
admin.site.register(PlanAlimentacion)
admin.site.register(Comida)
admin.site.register(Progreso)