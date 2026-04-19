from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import (
    Usuario, PlanEntrenamiento, Ejercicio, PlanAlimentacion,
    Comida, Progreso, Conversacion, RutinaEjercicio, RutinaComida,
    RegistroActividad, ProgresoAlimentacion
)


@admin.register(Usuario)
class UsuarioAdmin(UserAdmin):
    list_display = ('email', 'username', 'is_active', 'is_staff', 'date_joined')
    ordering = ('-date_joined',)
    fieldsets = UserAdmin.fieldsets + (
        ('Información física', {'fields': ('edad', 'peso', 'altura', 'objetivo')}),
    )


@admin.register(Conversacion)
class ConversacionAdmin(admin.ModelAdmin):
    list_display = ('usuario', 'tipo', 'fecha')
    list_filter = ('tipo',)
    ordering = ('-fecha',)


@admin.register(RutinaEjercicio)
class RutinaEjercicioAdmin(admin.ModelAdmin):
    list_display = ('nombre', 'grupo_muscular', 'plan', 'orden')
    list_filter = ('grupo_muscular',)
    ordering = ('plan', 'orden')


@admin.register(RutinaComida)
class RutinaComidaAdmin(admin.ModelAdmin):
    list_display = ('nombre', 'momento', 'plan', 'calorias', 'orden')
    list_filter = ('momento',)
    ordering = ('plan', 'orden')


@admin.register(RegistroActividad)
class RegistroActividadAdmin(admin.ModelAdmin):
    list_display = ('usuario', 'sesion_numero', 'fecha', 'plan')
    list_filter = ('fecha',)
    ordering = ('-fecha',)


@admin.register(ProgresoAlimentacion)
class ProgresoAlimentacionAdmin(admin.ModelAdmin):
    list_display = ('usuario', 'fecha', 'nivel_cumplimiento', 'calorias_consumidas')
    list_filter = ('nivel_cumplimiento', 'fecha')
    ordering = ('-fecha',)


admin.site.register(PlanEntrenamiento)
admin.site.register(Ejercicio)
admin.site.register(PlanAlimentacion)
admin.site.register(Comida)
admin.site.register(Progreso)