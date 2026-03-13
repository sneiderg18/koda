from django.shortcuts import render
from .models import Ejercicio

def inicio(request):
    return render(request, "usuarios/inicio.html")

def lista_ejercicios(request):
    ejercicios = Ejercicio.objects.all()
    return render(request, "usuarios/ejercicios.html", {"ejercicios": ejercicios})