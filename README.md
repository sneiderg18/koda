# Koda — App de Rutinas y Nutrición con IA

Koda es una aplicación móvil que genera rutinas de ejercicio y planes de alimentación personalizados usando inteligencia artificial (Google Gemini 2.5 Flash). El usuario ingresa sus datos físicos y objetivos, y recibe un plan completo adaptado a su perfil que puede seguir día a día.

---

## Tecnologías

| Capa            | Tecnología                                      |
|-----------------|-------------------------------------------------|
| App móvil       | Flutter                                         |
| Backend         | Django 5.2 + Django REST Framework              |
| Autenticación   | SimpleJWT                                       |
| Base de datos   | MySQL                                           |
| IA              | Google Gemini 2.5 Flash                         |
| Despliegue      | Railway (backend + MySQL)                       |
| Lenguaje        | Python 3.12                                     |

---

## Funcionalidades

- Registro e inicio de sesión con JWT
- Onboarding con datos físicos, objetivos, lesiones y restricciones alimentarias
- Generación de plan de entrenamiento personalizado con IA
- Generación de plan de alimentación con recetas completas (ingredientes y preparación)
- Sesión de entrenamiento en tiempo real — ejercicio por ejercicio con timer de descanso
- Marcado de comidas diarias — completado / omitido / sin marcar
- Registro de progreso de peso con historial
- Coach IA — chat libre que conoce el perfil completo del usuario y puede actualizarlo
- Calendario mensual de constancia — días que entrenó y cumplió alimentación
- Racha de días consecutivos usando la app
- Resumen de progreso con análisis opcional de IA
- La IA regenera el plan si el usuario no puede hacer un ejercicio o no le gusta un alimento
- Rotación de ejercicios por grupo muscular para evitar repetición

---

## Arquitectura del sistema

```
Flutter (App móvil)
        ↕  HTTPS + JWT
API REST (Django REST Framework)
        ↕
  MySQL (Base de datos)
        ↕
  Google Gemini 2.5 Flash (IA)
```

---

## Producción

El backend está desplegado en Railway y es la URL que usa la app:

```
https://koda-production-339d.up.railway.app
```

Cada `git push` a la rama `main` despliega automáticamente. No hay que hacer nada manual en Railway.

---

## Instalación local — Backend (Django)

### 1. Clonar el repositorio

```bash
git clone https://github.com/sneiderg18/koda.git
cd koda/backend/la_trainer
```

### 2. Crear entorno virtual e instalar dependencias

```bash
python -m venv env

# Windows
env\Scripts\activate

# Mac / Linux
source env/bin/activate

pip install -r requirements.txt
```

### 3. Configurar variables de entorno

Crea un archivo `.env` dentro de `backend/la_trainer/` con este contenido:

```
SECRET_KEY=una_clave_secreta_larga_y_aleatoria
DEBUG=True
DB_NAME=ia_trainer
DB_USER=root
DB_PASSWORD=tu_contraseña_mysql
DB_HOST=localhost
DB_PORT=3306
GEMINI_API_KEY=tu_clave_de_gemini
```

> El archivo `.env` **nunca** se sube al repositorio. Está en el `.gitignore`.

### 4. Crear la base de datos en MySQL

Abre MySQL y ejecuta:

```sql
CREATE DATABASE ia_trainer CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 5. Aplicar migraciones

```bash
python manage.py migrate
```

### 6. Ejecutar servidor local

```bash
python manage.py runserver
```

El servidor queda disponible en `http://localhost:8000`.

---

## Instalación local — App móvil (Flutter)

### 1. Ir a la carpeta del proyecto Flutter

```bash
cd koda/frontend/la_trainer_app
```

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Configurar la URL del backend

Abre `lib/config/api_config.dart` y elige la URL según desde dónde pruebes:

```dart
class ApiConfig {
  // Producción (Railway) — URL por defecto
  static const String baseUrl = 'https://koda-production-339d.up.railway.app';

  // Android Emulator (descomenta si pruebas en emulador):
  // static const String baseUrl = 'http://10.0.2.2:8000';

  // Dispositivo físico en la misma red WiFi (reemplaza con tu IP):
  // static const String baseUrl = 'http://192.168.1.X:8000';
}
```

### 4. Ejecutar la app

```bash
flutter run
```

---

## Flujo completo de la app

```
Registro → Onboarding → IA genera plan → Sesión ejercicio x ejercicio → Plan completo → Nuevo plan
```

1. El usuario se registra con email y contraseña
2. Completa el onboarding con sus datos físicos y objetivos
3. El coach IA genera un plan de entrenamiento y uno de alimentación
4. Cada día el usuario hace su sesión — marca ejercicios completados
5. Al terminar la sesión la app registra el día en el calendario
6. El usuario marca sus comidas del día como completadas u omitidas
7. La racha y el calendario se actualizan automáticamente
8. Al completar el plan la IA genera uno nuevo ajustado al progreso real

---

## Endpoints principales

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/api/registro/` | Registro de usuario |
| POST | `/api/login/` | Login — devuelve JWT |
| POST | `/api/token/refresh/` | Refrescar token |
| GET/PUT | `/api/perfil/` | Ver y editar perfil |
| POST | `/api/onboarding/` | Guardar datos físicos iniciales |
| POST | `/api/ia/plan/entrenamiento/` | Generar plan de entrenamiento con IA |
| POST | `/api/ia/plan/alimentacion/` | Generar plan de alimentación con IA |
| GET | `/api/planes/entrenamiento/activo/` | Plan de entrenamiento activo |
| GET | `/api/planes/alimentacion/activo/` | Plan de alimentación activo |
| POST | `/api/sesion/iniciar/` | Iniciar sesión de entrenamiento |
| GET | `/api/sesion/activa/` | Obtener sesión activa |
| POST | `/api/sesion/{id}/ejercicio/{id}/completar/` | Completar un ejercicio |
| POST | `/api/progreso/alimentacion/` | Registrar cumplimiento diario de alimentación |
| POST | `/api/acceso/` | Registrar acceso diario — actualiza racha |
| GET | `/api/progreso/resumen/` | Dashboard completo de progreso |
| GET | `/api/progreso/calendario/` | Calendario mensual de constancia |
| POST | `/api/ia/coach/` | Chat con el coach IA |
| GET | `/api/ia/historial/` | Historial de conversaciones |

> Todos los endpoints excepto `/api/registro/` y `/api/login/` requieren el header:
> `Authorization: Bearer <access_token>`

---

## Despliegue en Railway

El proyecto está configurado para desplegarse automáticamente en Railway desde la rama `main`.

**Archivos de configuración incluidos:**
- `Procfile` — comando de arranque del servidor
- `runtime.txt` — versión de Python
- `railway.toml` — migraciones automáticas en cada deploy

**Variables de entorno requeridas en Railway:**

| Variable | Descripción |
|----------|-------------|
| `SECRET_KEY` | Clave secreta de Django |
| `DEBUG` | `False` en producción |
| `GEMINI_API_KEY` | Clave de Google Gemini |
| `ALLOWED_HOSTS` | Dominio de Railway |
| `DB_HOST` | Inyectado automáticamente por Railway MySQL |
| `DB_NAME` | Inyectado automáticamente por Railway MySQL |
| `DB_USER` | Inyectado automáticamente por Railway MySQL |
| `DB_PASSWORD` | Inyectado automáticamente por Railway MySQL |
| `DB_PORT` | `3306` |

**Flujo de despliegue:**

```
git push origin main
        ↓
Railway detecta el cambio
        ↓
pip install -r requirements.txt
        ↓
python manage.py migrate (automático)
        ↓
python manage.py collectstatic (automático)
        ↓
gunicorn la_trainer.wsgi (servidor listo)
```

---

## Estructura del proyecto

```
koda/
├── backend/
│   └── la_trainer/
│       ├── la_trainer/          # Configuración Django
│       │   ├── settings.py
│       │   ├── urls.py
│       │   └── wsgi.py
│       ├── usuarios/            # App principal
│       │   ├── models.py        # Modelos de BD
│       │   ├── api_views.py     # Vistas de la API
│       │   ├── ia_views.py      # Vistas de IA
│       │   ├── ia_service.py    # Integración con Gemini
│       │   ├── serializers.py   # Serializadores
│       │   ├── api_urls.py      # Rutas de la API
│       │   └── validators.py    # Validadores de contraseña
│       ├── Procfile
│       ├── railway.toml
│       ├── runtime.txt
│       └── requirements.txt
└── frontend/
    └── la_trainer_app/
        └── lib/
            ├── config/
            │   └── api_config.dart
            ├── services/
            │   └── auth_service.dart
            └── screens/         # Pantallas de la app
```

---

## Seguridad

- Contraseñas con validadores estrictos — mínimo 8 caracteres, mayúsculas, minúsculas, 4 números y un carácter especial
- JWT con expiración de 30 minutos y refresh token de 7 días
- Cookies con HttpOnly y SameSite
- HTTPS forzado en producción vía Railway
- CORS restringido en producción

---

## Desarrolladores

- Luis Sneider
- Nick Duran
- Miguel Molina

Proyecto académico — 2026