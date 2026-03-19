import re
from django.core.exceptions import ValidationError


class MayusculasValidator:
    def validate(self, password, user=None):
        if not re.search(r'[A-Z]', password):
            raise ValidationError(
                'La contraseña debe tener al menos una letra mayúscula.',
                code='password_no_mayuscula'
            )

    def get_help_text(self):
        return 'Tu contraseña debe tener al menos una letra mayúscula.'


class MinusculasValidator:
    def validate(self, password, user=None):
        if not re.search(r'[a-z]', password):
            raise ValidationError(
                'La contraseña debe tener al menos una letra minúscula.',
                code='password_no_minuscula'
            )

    def get_help_text(self):
        return 'Tu contraseña debe tener al menos una letra minúscula.'


class NumerosValidator:
    def validate(self, password, user=None):
        numeros = re.findall(r'[0-9]', password)
        if len(numeros) < 4:
            raise ValidationError(
                'La contraseña debe tener al menos 4 números.',
                code='password_pocos_numeros'
            )

    def get_help_text(self):
        return 'Tu contraseña debe tener al menos 4 números.'


class CaracterEspecialValidator:
    def validate(self, password, user=None):
        if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-\+\=\[\]\/\\]', password):
            raise ValidationError(
                'La contraseña debe tener al menos un carácter especial (!@#$%^&*...).',
                code='password_no_especial'
            )

    def get_help_text(self):
        return 'Tu contraseña debe tener al menos un carácter especial.'