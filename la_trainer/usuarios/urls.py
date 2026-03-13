from django.urls import path
from . import views

urlpatterns = [
    path('', views.inicio, name='inicio'),
    path('ejercicios/', views.lista_ejercicios, name='ejercicios'),
]