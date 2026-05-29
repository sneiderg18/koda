import os
import json
import re
import time
from google import genai

cliente = genai.Client(api_key=os.getenv('GEMINI_API_KEY'))
# gemini-2.0-flash es mas estable para instrucciones de formato estricto
MODELO = 'gemini-2.0-flash'


def _llamar_gemini(prompt, max_reintentos=3):
    """
    Llama a Gemini con reintentos automaticos si hay error 503.
    Espera 2, 4, 8 segundos entre intentos (backoff exponencial).
    """
    ultimo_error = None
    for intento in range(max_reintentos):
        try:
            return cliente.models.generate_content(model=MODELO, contents=prompt)
        except Exception as e:
            ultimo_error = e
            error_str = str(e)
            if '503' in error_str or 'UNAVAILABLE' in error_str or 'high demand' in error_str:
                if intento < max_reintentos - 1:
                    espera = 2 ** (intento + 1)
                    time.sleep(espera)
                    continue
            raise
    raise ultimo_error


def _limpiar_json(texto):
    """
    Limpia el texto de Gemini para extraer el JSON puro.
    Maneja bloques ```json ... ```, texto libre antes/despues, y
    el bloque <think>...</think> que produce gemini-2.5-flash.
    """
    texto = texto.strip()
    # Quitar bloque <think> que genera gemini-2.5-flash
    texto = re.sub(r'<think>.*?</think>', '', texto, flags=re.DOTALL).strip()
    # Quitar bloques de codigo markdown
    if '```' in texto:
        partes = texto.split('```')
        for parte in partes:
            parte = parte.strip()
            if parte.startswith('json'):
                parte = parte[4:].strip()
            if parte.startswith('{') or parte.startswith('['):
                return parte.strip()
    # Buscar el primer { o [ del texto
    inicio = -1
    for i, c in enumerate(texto):
        if c in ('{', '['):
            inicio = i
            break
    if inicio >= 0:
        return texto[inicio:].strip()
    return texto



def _imagen_comida(nombre_comida):
    """
    Devuelve una URL de imagen para la comida.
    Por ahora retorna cadena vacia — las imagenes de comida
    se muestran en Flutter con un widget por categoria/momento.
    """
    return ''




# Cache global del indice de ejercicios (se carga una sola vez por proceso)
_EJERCICIOS_DB = None
_BASE_IMG_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"


def _cargar_db_ejercicios():
    global _EJERCICIOS_DB
    if _EJERCICIOS_DB is not None:
        return _EJERCICIOS_DB
    import urllib.request
    import json as _json
    try:
        url = ("https://raw.githubusercontent.com/yuhonas/"
               "free-exercise-db/main/dist/exercises.json")
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as r:
            _EJERCICIOS_DB = _json.loads(r.read())
    except Exception:
        _EJERCICIOS_DB = []
    return _EJERCICIOS_DB


def _buscar_imagen_ejercicio(nombre_ejercicio, grupo_muscular=""):
    db = _cargar_db_ejercicios()
    if not db:
        return ""

    terminos_nombre = {
        "press": "press", "sentadilla": "squat", "peso muerto": "deadlift",
        "dominada": "pull", "fondos": "dip", "plancha": "plank",
        "remo": "row", "curl": "curl", "extension": "extension",
        "elevacion": "raise", "apertura": "fly", "burpee": "burpee",
        "zancada": "lunge", "hip thrust": "hip", "crunch": "crunch",
        "press militar": "overhead", "jalon": "pulldown",
        "vuelo": "fly", "patada": "kickback",
    }

    musculo_map = {
        "pecho": "chest", "espalda": "lats", "hombros": "shoulders",
        "biceps": "biceps", "triceps": "triceps", "piernas": "quadriceps",
        "cuadriceps": "quadriceps", "isquiotibiales": "hamstrings",
        "gluteos": "glutes", "abdomen": "abdominals", "pantorrillas": "calves",
        "antebrazos": "forearms", "trapecio": "traps",
        "espalda baja": "lower back", "espalda media": "middle back",
    }

    nombre_lower = nombre_ejercicio.lower()
    musculo_lower = grupo_muscular.lower().strip()

    musculo_en = None
    for es, en in musculo_map.items():
        if es in musculo_lower:
            musculo_en = en
            break

    termino_en = None
    for es, en in terminos_nombre.items():
        if es in nombre_lower:
            termino_en = en
            break

    def _url(e):
        imgs = e.get("images", [])
        return (_BASE_IMG_URL + imgs[0]) if imgs else ""

    if termino_en and musculo_en:
        for e in db:
            if termino_en in e["name"].lower() and musculo_en in e.get("primaryMuscles", []):
                u = _url(e)
                if u:
                    return u

    if termino_en:
        for e in db:
            if termino_en in e["name"].lower():
                u = _url(e)
                if u:
                    return u

    if musculo_en:
        for e in db:
            if musculo_en in e.get("primaryMuscles", []):
                u = _url(e)
                if u:
                    return u

    return ""


def generar_plan_entrenamiento(usuario):
    prompt = f"""
    Eres un entrenador personal experto. Genera un plan de entrenamiento personalizado en español.

    Datos del usuario:
    - Nombre: {usuario.username}
    - Edad: {usuario.edad or 'No especificada'}
    - Peso: {usuario.peso or 'No especificado'} kg
    - Altura: {usuario.altura or 'No especificada'} cm
    - Objetivo: {usuario.objetivo or 'No especificado'}
    - Nivel de actividad: {usuario.nivel_actividad or 'No especificado'}
    - Dias de entrenamiento: {usuario.dias_entrenamiento or 'No especificado'}
    - Tiempo por sesion: {usuario.tiempo_sesion or 'No especificado'} min
    - Lugar: {usuario.lugar_entrenamiento or 'No especificado'}
    - Tiene equipo: {'Si' if usuario.tiene_equipo else 'No'}
    - Condiciones medicas: {usuario.condiciones_medicas or 'Ninguna'}
    - Lesiones: {usuario.lesiones or 'Ninguna'}

    Responde SOLO con un JSON valido con esta estructura exacta (sin texto adicional):
    {{
        "nivel": "Principiante/Intermedio/Avanzado",
        "tipo_entrenamiento": "tipo de entrenamiento",
        "duracion": numero_de_semanas,
        "descripcion": "descripcion general del plan",
        "ejercicios": [
            {{
                "nombre": "nombre del ejercicio",
                "series": numero,
                "repeticiones": numero,
                "descanso": "tiempo de descanso",
                "grupo_muscular": "grupo muscular"
            }}
        ]
    }}
    """
    respuesta = _llamar_gemini(prompt)
    resultado = json.loads(_limpiar_json(respuesta.text))

    for ejercicio in resultado.get('ejercicios', []):
        imagen = _buscar_imagen_ejercicio(
            ejercicio.get('nombre', ''),
            ejercicio.get('grupo_muscular', '')
        )
        ejercicio['imagen_url'] = imagen

    return resultado


def generar_plan_alimentacion(usuario, plan_anterior=None):
    """
    Genera un plan de alimentacion personalizado.
    Si existe un plan_anterior completado, la IA lo usa como contexto
    para ajustar calorias y macros segun el progreso real del usuario.
    """
    progreso_alimentacion = usuario.progreso_alimentacion.all()[:14]
    historial_alimentacion = ''
    if progreso_alimentacion:
        historial_alimentacion = '\n'.join([
            f"- {p.fecha}: cumplimiento={p.nivel_cumplimiento}, "
            f"calorias={p.calorias_consumidas or 'no registrado'}, "
            f"agua={p.agua_consumida or 'no registrado'}L, notas={p.notas or 'ninguna'}"
            for p in progreso_alimentacion
        ])

    info_plan_anterior = ''
    if plan_anterior:
        info_plan_anterior = f"""
    Plan anterior completado:
    - Calorias diarias: {plan_anterior.calorias} kcal
    - Objetivo: {plan_anterior.objetivo}
    - Dias completados: {plan_anterior.dias_completados} de {plan_anterior.duracion_dias}
    """

    comidas_por_dia = usuario.comidas_por_dia or 3

    prompt = f"""
    Eres un nutricionista experto. Genera un plan de alimentacion COMPLETO y DETALLADO personalizado en espanol.
    {"Este es un plan de SEGUIMIENTO basado en el progreso registrado. Ajusta calorias y macros segun el avance." if plan_anterior else "Este es el PRIMER plan del usuario."}

    Datos del usuario:
    - Nombre: {usuario.username}
    - Edad: {usuario.edad or 'No especificada'}
    - Peso: {usuario.peso or 'No especificado'} kg
    - Altura: {usuario.altura or 'No especificada'} cm
    - Objetivo: {usuario.objetivo or 'No especificado'}
    - Alergias: {usuario.alergias or 'Ninguna'}
    - Restricciones alimentarias: {usuario.restricciones_alimentarias or 'Ninguna'}
    - Comidas por dia: {comidas_por_dia}
    - Condiciones medicas: {usuario.condiciones_medicas or 'Ninguna'}
    {info_plan_anterior}
    Historial de cumplimiento (ultimos 14 dias):
    {historial_alimentacion if historial_alimentacion else 'Sin registros aun - primer plan'}

    INSTRUCCIONES:
    - Genera EXACTAMENTE {comidas_por_dia} comidas (segun las comidas por dia del usuario)
    - Cada comida debe tener receta COMPLETA con ingredientes y pasos de preparacion
    - Los ingredientes deben incluir cantidades exactas (gramos, tazas, unidades)
    - La preparacion debe ser clara, paso a paso, en espanol sencillo
    - Si el cumplimiento fue "excelente" o "bueno" de forma consistente, ajusta levemente las calorias
    - Si el cumplimiento fue "regular" o "malo", simplifica las recetas para que sean mas faciles de seguir
    - Respeta estrictamente las alergias y restricciones alimentarias
    - VARÍA las comidas — no repitas los mismos alimentos del plan anterior

    Responde SOLO con un JSON valido con esta estructura exacta (sin texto adicional antes ni despues):
    {{
        "calorias_diarias": numero,
        "objetivo": "objetivo nutricional",
        "descripcion": "descripcion general del plan",
        "duracion_dias": 30,
        "comidas": [
            {{
                "nombre": "nombre de la comida",
                "momento": "Desayuno/Almuerzo/Cena/Merienda",
                "calorias": numero,
                "proteinas": numero,
                "carbohidratos": numero,
                "grasas": numero,
                "descripcion": "descripcion breve de la comida",
                "ingredientes": "- 2 huevos\\n- 1 taza de avena (90g)\\n- 1 banano\\n- 200ml leche descremada",
                "preparacion": "1. Calentar la leche a fuego medio.\\n2. Agregar la avena y revolver 5 minutos.\\n3. Servir con el banano en rodajas.",
                "tiempo_preparacion": 15
            }}
        ]
    }}
    """
    respuesta = _llamar_gemini(prompt)
    resultado = json.loads(_limpiar_json(respuesta.text))

    for comida in resultado.get('comidas', []):
        comida['imagen_url'] = _imagen_comida(comida.get('nombre', ''))

    return resultado


def analizar_progreso(usuario):
    progresos = usuario.progresos.all()[:10]
    historial = '\n'.join([
        f"- Fecha: {p.fecha}, Peso: {p.peso}kg, Observaciones: {p.observaciones}"
        for p in progresos
    ])

    from datetime import date, timedelta
    from .models import RegistroAcceso
    hace_7_dias = date.today() - timedelta(days=7)
    registros_recientes = RegistroAcceso.objects.filter(
        usuario=usuario,
        fecha__gte=hace_7_dias,
        entreno=True
    ).exclude(grupos_musculares='')

    grupos_semana = []
    for r in registros_recientes:
        if r.grupos_musculares:
            grupos_semana.extend(r.grupos_musculares.split(', '))

    from collections import Counter
    conteo_grupos = Counter(grupos_semana)
    grupos_mas_trabajados = ', '.join([f"{g} ({c}x)" for g, c in conteo_grupos.most_common()])
    grupos_poco_trabajados = [g for g, c in conteo_grupos.items() if c == 1]

    sesiones_recientes = RegistroAcceso.objects.filter(
        usuario=usuario,
        entreno=True,
        fecha__gte=hace_7_dias
    ).order_by('-fecha')[:7]

    historial_sesiones = '\n'.join([
        f"- {r.fecha}: grupos trabajados: {r.grupos_musculares or 'no registrado'}"
        for r in sesiones_recientes
    ])

    prompt = f"""
    Eres un entrenador personal experto. Analiza el progreso del usuario y ajusta su plan.

    Datos del usuario:
    - Nombre: {usuario.username}
    - Objetivo: {usuario.objetivo or 'No especificado'}

    Historial de peso (ultimos registros):
    {historial if historial else 'Sin registros de peso aun'}

    Sesiones de entrenamiento (ultimos 7 dias):
    {historial_sesiones if historial_sesiones else 'Sin sesiones registradas'}

    Grupos musculares mas trabajados esta semana: {grupos_mas_trabajados or 'Ninguno aun'}
    Grupos musculares poco trabajados: {', '.join(grupos_poco_trabajados) if grupos_poco_trabajados else 'Todos equilibrados'}

    Responde SOLO con un JSON valido con esta estructura exacta (sin texto adicional):
    {{
        "analisis": "analisis detallado del progreso incluyendo equilibrio muscular",
        "esta_progresando": true,
        "recomendacion": "recomendacion principal",
        "ajustes_plan": "ajustes sugeridos al plan de entrenamiento segun grupos musculares trabajados",
        "ajustes_alimentacion": "ajustes sugeridos al plan de alimentacion",
        "grupos_descansados": "grupos musculares que deben descansar hoy",
        "grupos_sugeridos": "grupos musculares recomendados para entrenar hoy"
    }}
    """
    respuesta = _llamar_gemini(prompt)
    return json.loads(_limpiar_json(respuesta.text))


def chat_coach(usuario, mensaje):
    # Traer las ultimas 10 conversaciones en orden cronologico correcto
    historial = list(
        usuario.conversaciones.filter(tipo='coach').order_by('-fecha')[:10]
    )
    historial.reverse()
    contexto = '\n'.join([
        f"Usuario: {c.mensaje_usuario}\nCoach: {c.respuesta_ia}"
        for c in historial
    ])

    progresos = usuario.progresos.all()[:3]
    progreso_reciente = '\n'.join([
        f"- {p.fecha}: {p.peso}kg"
        for p in progresos
    ])

    campos_faltantes = []
    if not usuario.nivel_actividad:
        campos_faltantes.append('nivel de actividad')
    if not usuario.condiciones_medicas:
        campos_faltantes.append('condiciones medicas')
    if not usuario.alergias:
        campos_faltantes.append('alergias alimentarias')
    if not usuario.lesiones:
        campos_faltantes.append('lesiones o limitaciones fisicas')
    if not usuario.restricciones_alimentarias:
        campos_faltantes.append('restricciones alimentarias')
    if not usuario.dias_entrenamiento:
        campos_faltantes.append('dias de entrenamiento por semana')
    if not usuario.tiempo_sesion:
        campos_faltantes.append('tiempo por sesion')
    if not usuario.lugar_entrenamiento:
        campos_faltantes.append('lugar de entrenamiento')

    perfil_completo = f"""
    Datos del usuario:
    - Nombre: {usuario.username}
    - Edad: {usuario.edad or 'No especificada'}
    - Peso: {usuario.peso or 'No especificado'} kg
    - Altura: {usuario.altura or 'No especificada'} cm
    - Genero: {usuario.genero or 'No especificado'}
    - Objetivo: {usuario.objetivo or 'No especificado'}
    - Objetivo de tiempo: {usuario.objetivo_tiempo or 'No especificado'}
    - Motivacion: {usuario.motivacion or 'No especificada'}
    - Nivel de actividad: {usuario.nivel_actividad or 'No especificado'}
    - Dias de entrenamiento: {usuario.dias_entrenamiento or 'No especificado'}
    - Tiempo por sesion: {usuario.tiempo_sesion or 'No especificado'} min
    - Lugar: {usuario.lugar_entrenamiento or 'No especificado'}
    - Tiene equipo: {'Si' if usuario.tiene_equipo else 'No'}
    - Condiciones medicas: {usuario.condiciones_medicas or 'Ninguna'}
    - Alergias: {usuario.alergias or 'Ninguna'}
    - Lesiones: {usuario.lesiones or 'Ninguna'}
    - Restricciones alimentarias: {usuario.restricciones_alimentarias or 'Ninguna'}
    - Comidas por dia: {usuario.comidas_por_dia or 'No especificado'}
    - Agua por dia: {usuario.agua_por_dia or 'No especificado'} litros
    - Calidad del sueno: {usuario.calidad_sueno or 'No especificada'}
    - Nivel de estres: {usuario.nivel_estres or 'No especificado'}
    """

    # Obtener plan de alimentacion activo para contexto
    plan_alimentacion_activo = usuario.planes_alimentacion.filter(activo=True).last()
    info_plan_alimentacion = ''
    if plan_alimentacion_activo:
        comidas = plan_alimentacion_activo.rutina_comidas.all()
        nombres_comidas = ', '.join([c.nombre for c in comidas])
        info_plan_alimentacion = f"Plan de alimentacion activo con estas comidas: {nombres_comidas}"

    # Obtener plan de entrenamiento activo para contexto
    plan_entrenamiento_activo = usuario.planes_entrenamiento.filter(activo=True).last()
    info_plan_entrenamiento = ''
    if plan_entrenamiento_activo:
        ejercicios = plan_entrenamiento_activo.rutina_ejercicios.all()
        nombres_ejercicios = ', '.join([f"{e.nombre} ({e.grupo_muscular})" for e in ejercicios])
        info_plan_entrenamiento = f"Plan de entrenamiento activo con estos ejercicios: {nombres_ejercicios}"

    prompt = f"""
    Eres TrainerIA, un coach personal experto, empatico y motivador.
    Responde en espanol de forma amigable y personalizada.

    {perfil_completo}

    Progreso reciente:
    {progreso_reciente if progreso_reciente else 'Sin registros aun'}

    Historial de conversacion:
    {contexto if contexto else 'Primera conversacion'}

    {info_plan_alimentacion if info_plan_alimentacion else 'El usuario no tiene plan de alimentacion activo.'}
    {info_plan_entrenamiento if info_plan_entrenamiento else 'El usuario no tiene plan de entrenamiento activo.'}

    Campos del perfil que faltan completar:
    {', '.join(campos_faltantes) if campos_faltantes else 'Perfil completo'}

    Mensaje del usuario: {mensaje}

    INSTRUCCIONES IMPORTANTES — LEE CADA UNA CON ATENCION:
    1. Responde de forma natural y motivadora. Maximo 3 parrafos cortos.
    2. Si hay campos faltantes y es buena oportunidad, pregunta UNO solo de forma natural.
    3. Si el usuario quiere modificar algun dato de su perfil, actualiza y agrega al FINAL de tu respuesta:
       {{"actualizar_perfil": {{"campo": "valor"}}}}
    4. REGLA CRITICA DE ALIMENTACION: Si el usuario dice que no le gusta, no quiere, le cae mal,
       no puede comprar, no tiene, quiere evitar, o quiere cambiar CUALQUIER alimento o comida,
       debes responder que entendiste y que ya le generas un nuevo plan adaptado.
       Agrega al FINAL de tu respuesta (en una linea separada, sin texto despues):
       {{"regenerar_plan_alimentacion": true, "motivo": "breve razon"}}
       NO preguntes si quiere cambiar — hazlo directamente siempre.
    5. REGLA CRITICA DE ENTRENAMIENTO: Si el usuario dice que no puede hacer, le duele, no le gusta,
       o quiere evitar CUALQUIER ejercicio o movimiento,
       debes responder que entendiste y que ya le ajustas el plan.
       Agrega al FINAL de tu respuesta (en una linea separada, sin texto despues):
       {{"regenerar_plan_entrenamiento": true, "motivo": "breve razon"}}
       NO preguntes si quiere cambiar — hazlo directamente siempre.
    6. NUNCA incluyas mas de un JSON al final. Si aplican reglas 3 y 4 juntas, combinalas.
    7. NUNCA pongas texto despues del JSON final.
    """

    respuesta = _llamar_gemini(prompt)
    texto = respuesta.text.strip()

    # Quitar bloque <think> si gemini lo incluye
    texto = re.sub(r'<think>.*?</think>', '', texto, flags=re.DOTALL).strip()

    # ── Procesar actualizacion de perfil ──────────────────────
    if '"actualizar_perfil"' in texto:
        try:
            json_match = re.search(r'\{"actualizar_perfil":\s*\{[^}]+\}\}', texto)
            if json_match:
                datos = json.loads(json_match.group())
                campos = datos.get('actualizar_perfil', {})
                for campo, valor in campos.items():
                    if hasattr(usuario, campo):
                        setattr(usuario, campo, valor)
                usuario.save()
                texto = texto[:json_match.start()].strip()
        except Exception:
            pass

    # ── Procesar regeneracion de plan de alimentacion ─────────
    if '"regenerar_plan_alimentacion"' in texto:
        # Extraer y limpiar el JSON del texto
        json_match = re.search(
            r'\{"regenerar_plan_alimentacion":\s*true[^}]*\}', texto
        )
        if json_match:
            texto = texto[:json_match.start()].strip()

        error_regeneracion = None
        try:
            # Desactivar plan actual
            if plan_alimentacion_activo:
                plan_alimentacion_activo.activo = False
                plan_alimentacion_activo.completado = True
                plan_alimentacion_activo.save()

            # Generar nuevo plan
            nuevo_plan_data = generar_plan_alimentacion(usuario)

            from .models import PlanAlimentacion, RutinaComida
            nuevo_plan = PlanAlimentacion.objects.create(
                usuario=usuario,
                calorias=nuevo_plan_data.get('calorias_diarias', 2000),
                objetivo=nuevo_plan_data.get('objetivo', ''),
                duracion_dias=nuevo_plan_data.get('duracion_dias', 30),
                activo=True,
            )
            momento_map = {
                'desayuno': 'desayuno', 'almuerzo': 'almuerzo',
                'cena': 'cena', 'merienda': 'merienda', 'snack': 'merienda',
            }
            for index, comida in enumerate(nuevo_plan_data.get('comidas', [])):
                momento = comida.get('momento', 'Almuerzo').lower()
                RutinaComida.objects.create(
                    plan=nuevo_plan,
                    nombre=comida.get('nombre', ''),
                    momento=momento_map.get(momento, 'merienda'),
                    calorias=comida.get('calorias', 0),
                    proteinas=comida.get('proteinas', 0),
                    carbohidratos=comida.get('carbohidratos', 0),
                    grasas=comida.get('grasas', 0),
                    descripcion=comida.get('descripcion', ''),
                    ingredientes=comida.get('ingredientes', ''),
                    preparacion=comida.get('preparacion', ''),
                    tiempo_preparacion=comida.get('tiempo_preparacion', 0),
                    imagen_url=comida.get('imagen_url', ''),
                    orden=index + 1
                )
            texto += '\n\n Tu nuevo plan de alimentacion ya esta listo. Recarga la pantalla de alimentacion para verlo.'
            texto += '\n{"plan_alimentacion_regenerado": true}'

        except Exception as e:
            error_regeneracion = str(e)
            # Reactivar plan anterior si fallo la generacion
            if plan_alimentacion_activo:
                plan_alimentacion_activo.activo = True
                plan_alimentacion_activo.completado = False
                plan_alimentacion_activo.save()
            texto += '\n\nHubo un problema generando el nuevo plan. Intentalo de nuevo en un momento.'

    # ── Procesar regeneracion de plan de entrenamiento ────────
    if '"regenerar_plan_entrenamiento"' in texto:
        json_match = re.search(
            r'\{"regenerar_plan_entrenamiento":\s*true[^}]*\}', texto
        )
        if json_match:
            texto = texto[:json_match.start()].strip()

        try:
            if plan_entrenamiento_activo:
                plan_entrenamiento_activo.activo = False
                plan_entrenamiento_activo.completado = True
                plan_entrenamiento_activo.save()

            nuevo_plan_data = generar_plan_entrenamiento(usuario)

            from .models import PlanEntrenamiento, RutinaEjercicio
            nuevo_plan = PlanEntrenamiento.objects.create(
                usuario=usuario,
                tipo_entrenamiento=nuevo_plan_data.get('tipo_entrenamiento', ''),
                nivel=nuevo_plan_data.get('nivel', 'Principiante'),
                duracion=nuevo_plan_data.get('duracion', 4),
                activo=True,
            )
            for index, ejercicio in enumerate(nuevo_plan_data.get('ejercicios', [])):
                RutinaEjercicio.objects.create(
                    plan=nuevo_plan,
                    nombre=ejercicio.get('nombre', ''),
                    grupo_muscular=ejercicio.get('grupo_muscular', ''),
                    series=ejercicio.get('series', 3),
                    repeticiones=ejercicio.get('repeticiones', 10),
                    descanso=ejercicio.get('descanso', '60 segundos'),
                    imagen_url=ejercicio.get('imagen_url', ''),
                    orden=index + 1
                )
            texto += '\n\n Tu nuevo plan de entrenamiento ya esta listo. Recarga la pantalla de ejercicios para verlo.'
            texto += '\n{"plan_entrenamiento_regenerado": true}'

        except Exception as e:
            if plan_entrenamiento_activo:
                plan_entrenamiento_activo.activo = True
                plan_entrenamiento_activo.completado = False
                plan_entrenamiento_activo.save()
            texto += '\n\nHubo un problema generando el nuevo plan de entrenamiento. Intentalo de nuevo en un momento.'

    return texto


def generar_descripcion_ejercicio(nombre, grupo_muscular):
    prompt = f"""
    Eres un entrenador personal experto. Describe el ejercicio en espanol.

    Ejercicio: {nombre}
    Grupo muscular: {grupo_muscular}

    Responde SOLO con un JSON valido con esta estructura exacta (sin texto adicional):
    {{
        "descripcion": "descripcion detallada del ejercicio",
        "musculos_secundarios": "musculos secundarios trabajados",
        "tecnica": "pasos para realizar el ejercicio correctamente",
        "errores_comunes": "errores comunes a evitar",
        "variaciones": "variaciones del ejercicio"
    }}
    """
    respuesta = _llamar_gemini(prompt)
    return json.loads(_limpiar_json(respuesta.text))