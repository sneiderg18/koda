# Koda — App de Rutinas y Nutrición con IA

Koda es una aplicación móvil que genera rutinas de ejercicio y planes de
alimentación personalizados usando inteligencia artificial. Los usuarios
ingresan sus datos físicos y objetivos (bajar peso, ganar masa muscular,
mejorar condición) y reciben recomendaciones adaptadas a su perfil.

---

## Tecnologías

| Capa          | Tecnología                         |
|---------------|------------------------------------|
| App móvil     | Flutter                            |
| Backend       | Django + Django REST Framework     |
| Base de datos | MySQL                              |
| Lenguaje      | Python 3.11+                       |

---

## Funcionalidades

- Registro e inicio de sesión de usuarios
- Ingreso de datos físicos y objetivos
- Generación de rutinas personalizadas con IA
- Plan de alimentación recomendado
- Seguimiento de progreso
- Notificaciones automáticas adaptadas al perfil

---

## Instalación — Backend (Django)

### 1. Clonar el repositorio
```bash
git clone https://github.com/sneiderg18/koda.git
cd koda
```

### 2. Crear entorno virtual e instalar dependencias
```bash
python -m venv env
source env/bin/activate      # En Windows: env\Scripts\activate
pip install -r requirements.txt
```

### 3. Configurar variables de entorno
Crea un archivo `.env` en la raíz del proyecto con:
```
SECRET_KEY=tu_clave_secreta
DEBUG=False
DB_NAME=koda_db
DB_USER=tu_usuario
DB_PASSWORD=tu_contraseña
DB_HOST=localhost
DB_PORT=3306
```

### 4. Aplicar migraciones y crear superusuario
```bash
python manage.py migrate
python manage.py createsuperuser
```

### 5. Ejecutar servidor
```bash
python manage.py runserver
```

---

## Instalación — App móvil (Flutter)

```bash
cd koda_app
flutter pub get
flutter run
```

---

## Arquitectura del sistema

```
Flutter (App móvil)
        ↕
API REST (Django REST Framework)
        ↕
  MySQL (Base de datos)
```

---

## Checklist antes de producción

- [ ] Archivo `.env.example` con las variables sin valores reales
- [ ] `.gitignore` que excluya `.env`, `env/`, `__pycache__/`, `*.pyc`
- [ ] `requirements.txt` actualizado (`pip freeze > requirements.txt`)
- [ ] `DEBUG=False` en producción
- [ ] Sin credenciales hardcodeadas en el código

---

## Desarrolladores

- Luis Sneider
- Nick Duran
- Miguel Molina

Proyecto académico — 2026
