from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Usuario, PlanEntrenamiento, Ejercicio, PlanAlimentacion, Comida, Progreso, Conversacion


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


admin.site.register(PlanEntrenamiento)
admin.site.register(Ejercicio)
admin.site.register(PlanAlimentacion)
admin.site.register(Comida)
admin.site.register(Progreso)