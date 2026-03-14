from django.shortcuts import render, redirect
from django.contrib.auth import login, logout, authenticate
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.views.decorators.http import require_http_methods
from .forms import RegistroForm, LoginForm
from .models import Ejercicio

def inicio (request):
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
        form = LoginForm(request, data=request.POST)
        if form.is_valid():
            usuario = form.get_user()
            login(request, usuario)
            messages.success(request, f'¡Bienvenido de nuevo, {usuario.username}!')
            next_url = request.GET.get('next', 'dashboard')
            return redirect(next_url)
        else:
            messages.error(request, 'Correo o contraseña incorrecta')
    else:
        form = LoginForm(request)
    return render(request, 'usuarios/login.html', {'form': form})


@require_http_methods(["POST"])
def cerrar_sesion(request):
    logout(request)
    messages.info(request, 'sesion cerrada correctamente.')
    return redirect('inicio')

@login_required(login_url='login')
def dashboard (request):
    return render(request, 'usuarios/dashboard.html',{
        'usuario': request.user
    })

@login_required(login_url='login')
def lista_ejercicios(request):
    ejercicios = Ejercicio.objects.all()
    return render (request, 'usuarios/ejercicios.html', {'ejercicios': ejercicios})