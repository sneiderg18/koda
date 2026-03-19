from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Usuario, PlanEntrenamiento, Ejercicio, PlanAlimentacion, Comida, Progreso


@admin.register(Usuario)
class UsuarioAdmin(UserAdmin):
    list_display = ('email', 'username', 'is_active', 'is_staff', 'date_joined')
    ordering = ('-date_joined',)
    fieldsets = UserAdmin.fieldsets + (
        ('Información física', {'fields': ('edad', 'peso', 'altura', 'objetivo')}),
    )


admin.site.register(PlanEntrenamiento)
admin.site.register(Ejercicio)
admin.site.register(PlanAlimentacion)
admin.site.register(Comida)
admin.site.register(Progreso)