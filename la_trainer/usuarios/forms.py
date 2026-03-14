from django import forms
from django.contrib.auth.forms import UserCreationForm, AuthenticationForm
from django.core.exceptions import ValidationError
from .models import Usuario


class RegistroForm(UserCreationForm):
    email = forms.EmailField(
        required=True,
        widget=forms.EmailInput(attrs={
            'class': 'form-input',
            'placeholder': 'correo@ejemplo.com',
            'autocomplete': 'email',
        })
    )


    username = forms.CharField(
        label='nombre de usuario',
        max_length=150,
        widget=forms.TextInput(attrs={
            'class': 'form-input',
            'placeholder': 'Tu nombre de usuario',
        })
    )


    password1 = forms.CharField(
        label='Contraseña',
        widget=forms.PasswordInput(attrs={
            'class': 'form-input',
            'placeholder': 'Escribe Contraseña',
            'autocomplete': 'new-password',
        })
    )


    password2 = forms.CharField(
        label='Confirmar contraseña',
        widget=forms.PasswordInput(attrs={
            'class': 'form-input',
            'placeholder': 'Escribe Contraseña',
            'autocomplete': 'new-password',
        })
    )

    class Meta:
        model = Usuario
        fields = ('email', 'username', 'password1', 'password2')


    def clean_email(self):
        email = self.cleaned_data.get('email', '').lower().strip()
        
        if Usuario.objects.filter(email=email).exists():
            raise ValidationError('Ya existe una cuenta con este correo.')
        return email
    

class LoginForm(AuthenticationForm):
    username = forms.EmailField(
        label='Correo electronico',
        widget=forms.EmailInput(attrs={
            'class': 'form-input',
            'placeholder': 'correo@ejemplo.com',
            'autocomplete': 'email',
            'autofocus': True,
        })
    )

    password = forms.CharField(
        label='contraseña',
        widget=forms.PasswordInput(attrs={
            'class': 'form-input',
            'placeholder': 'Escribe Contraseña',
            'autocomplete': 'current-password'
        })
    )