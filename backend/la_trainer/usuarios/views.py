from django.shortcuts import render, redirect
from django.contrib.auth import login, logout, authenticate
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.views.decorators.http import require_http_methods
from .forms import RegistroForm, LoginForm
from .models import Ejercicio, IntentoLogin


def _get_client_ip(request):
    """Obtiene la IP real del cliente."""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR', '0.0.0.0')


def inicio(request):
    if request.user.is_authenticated:
        return redirect('dashboard')
    return render(request, 'usuarios/inicio.html')


@require_http_methods(["GET", "POST"])
def registro(request):
    if request.user.is_authenticated:
        return redirect('dashboard')

    if request.method == 'POST':
        form = RegistroForm(request.POST)
        if form.is_valid():
            usuario = form.save()
            login(request, usuario, backend="django.contrib.auth.backends.ModelBackend")
            messages.success(request, f'¡Bienvenido, {usuario.username}!')
            return redirect('dashboard')
        else:
            messages.error(request, 'Por favor corregir los errores del formulario.')
    else:
        form = RegistroForm()

    return render(request, 'usuarios/registro.html', {'form': form})


@require_http_methods(["GET", "POST"])
def iniciar_sesion(request):
    if request.user.is_authenticated:
        return redirect('dashboard')

    if request.method == 'POST':
        email = request.POST.get('username', '').lower().strip()
        ip = _get_client_ip(request)

        # ── Verificar bloqueo ──────────────────────────────────
        bloqueado, segundos = IntentoLogin.esta_bloqueado(email, ip)
        if bloqueado:
            minutos = segundos // 60 + 1
            messages.error(
                request,
                f'Demasiados intentos fallidos. Intenta de nuevo en {minutos} minuto(s).'
            )
            return render(request, 'usuarios/login.html', {'form': LoginForm(request)})

        # ── Procesar formulario ────────────────────────────────
        form = LoginForm(request, data=request.POST)
        if form.is_valid():
            usuario = form.get_user()
            # Login exitoso — limpiar intentos y registrar éxito
            IntentoLogin.limpiar_intentos(email, ip)
            IntentoLogin.registrar_intento(email, ip, exitoso=True)
            login(request, usuario)
            messages.success(request, f'¡Bienvenido de nuevo, {usuario.username}!')
            next_url = request.GET.get('next', 'dashboard')
            return redirect(next_url)
        else:
            # Login fallido — registrar intento
            IntentoLogin.registrar_intento(email, ip, exitoso=False)

            # Contar cuántos intentos quedan
            _, segundos_restantes = IntentoLogin.esta_bloqueado(email, ip)
            if segundos_restantes > 0:
                minutos = segundos_restantes // 60 + 1
                messages.error(
                    request,
                    f'Cuenta bloqueada por demasiados intentos. Intenta en {minutos} minuto(s).'
                )
            else:
                # Calcular intentos restantes para mostrar advertencia
                from django.utils import timezone
                from datetime import timedelta
                desde = timezone.now() - timedelta(minutes=IntentoLogin.VENTANA_MINUTOS)
                from django.db.models import Q
                intentos_actuales = IntentoLogin.objects.filter(
                    fecha__gte=desde,
                    exitoso=False,
                ).filter(
                    Q(email=email) | Q(ip=ip)
                ).count()
                restantes = IntentoLogin.MAX_INTENTOS - intentos_actuales
                if restantes <= 2:
                    messages.error(
                        request,
                        f'Correo o contraseña incorrecta. Te quedan {restantes} intento(s) antes del bloqueo.'
                    )
                else:
                    messages.error(request, 'Correo o contraseña incorrecta.')
    else:
        form = LoginForm(request)

    return render(request, 'usuarios/login.html', {'form': form})


@require_http_methods(["POST"])
def cerrar_sesion(request):
    logout(request)
    messages.info(request, 'Sesión cerrada correctamente.')
    return redirect('inicio')


@login_required(login_url='login')
def dashboard(request):
    return render(request, 'usuarios/dashboard.html', {
        'usuario': request.user
    })


@login_required(login_url='login')
def lista_ejercicios(request):
    ejercicios = Ejercicio.objects.all()
    return render(request, 'usuarios/ejercicios.html', {'ejercicios': ejercicios})