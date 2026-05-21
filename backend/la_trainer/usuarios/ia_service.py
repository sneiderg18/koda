import os
import json
import re
from google import genai

cliente = genai.Client(api_key=os.getenv('GEMINI_API_KEY'))
MODELO = 'gemini-2.5-flash'


def _limpiar_json(texto):
    texto = texto.strip()
    if texto.startswith('```'):
        texto = texto.split('```')[1]
        if texto.startswith('json'):
            texto = texto[4:]
    return texto.strip()


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
    - Días de entrenamiento: {usuario.dias_entrenamiento or 'No especificado'}
    - Tiempo por sesión: {usuario.tiempo_sesion or 'No especificado'} min
    - Lugar: {usuario.lugar_entrenamiento or 'No especificado'}
    - Tiene equipo: {'Sí' if usuario.tiene_equipo else 'No'}
    - Condiciones médicas: {usuario.condiciones_medicas or 'Ninguna'}
    - Lesiones: {usuario.lesiones or 'Ninguna'}
    
    Responde SOLO con un JSON válido con esta estructura exacta:
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
    respuesta = cliente.models.generate_content(model=MODELO, contents=prompt)
    return json.loads(_limpiar_json(respuesta.text))


def generar_plan_alimentacion(usuario, plan_anterior=None):
    """
    Genera un plan de alimentación personalizado.
    Si existe un plan_anterior completado, la IA lo usa como contexto
    para ajustar calorías y macros según el progreso real del usuario.
    """
    # Construir historial de cumplimiento si existe
    progreso_alimentacion = usuario.progreso_alimentacion.all()[:14]
    historial_alimentacion = ''
    if progreso_alimentacion:
        historial_alimentacion = '\n'.join([
            f"- {p.fecha}: cumplimiento={p.nivel_cumplimiento}, "
            f"calorias={p.calorias_consumidas or 'no registrado'}, "
            f"agua={p.agua_consumida or 'no registrado'}L, notas={p.notas or 'ninguna'}"
            for p in progreso_alimentacion
        ])

    # Info del plan anterior si existe
    info_plan_anterior = ''
    if plan_anterior:
        info_plan_anterior = f"""
    Plan anterior completado:
    - Calorías diarias: {plan_anterior.calorias} kcal
    - Objetivo: {plan_anterior.objetivo}
    - Días completados: {plan_anterior.dias_completados} de {plan_anterior.duracion_dias}
    """

    comidas_por_dia = usuario.comidas_por_dia or 3

    prompt = f"""
    Eres un nutricionista experto. Genera un plan de alimentación COMPLETO y DETALLADO personalizado en español.
    {"Este es un plan de SEGUIMIENTO basado en el progreso registrado. Ajusta calorías y macros según el avance." if plan_anterior else "Este es el PRIMER plan del usuario."}

    Datos del usuario:
    - Nombre: {usuario.username}
    - Edad: {usuario.edad or 'No especificada'}
    - Peso: {usuario.peso or 'No especificado'} kg
    - Altura: {usuario.altura or 'No especificada'} cm
    - Objetivo: {usuario.objetivo or 'No especificado'}
    - Alergias: {usuario.alergias or 'Ninguna'}
    - Restricciones alimentarias: {usuario.restricciones_alimentarias or 'Ninguna'}
    - Comidas por día: {comidas_por_dia}
    - Condiciones médicas: {usuario.condiciones_medicas or 'Ninguna'}
    {info_plan_anterior}
    Historial de cumplimiento (últimos 14 días):
    {historial_alimentacion if historial_alimentacion else 'Sin registros aún - primer plan'}

    INSTRUCCIONES:
    - Genera EXACTAMENTE {comidas_por_dia} comidas (según las comidas por día del usuario)
    - Cada comida debe tener receta COMPLETA con ingredientes y pasos de preparación
    - Los ingredientes deben incluir cantidades exactas (gramos, tazas, unidades)
    - La preparación debe ser clara, paso a paso, en español sencillo
    - Si el cumplimiento fue "excelente" o "bueno" de forma consistente, ajusta levemente las calorías
    - Si el cumplimiento fue "regular" o "malo", simplifica las recetas para que sean más fáciles de seguir
    - Respeta estrictamente las alergias y restricciones alimentarias

    Responde SOLO con un JSON válido con esta estructura exacta:
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
    respuesta = cliente.models.generate_content(model=MODELO, contents=prompt)
    return json.loads(_limpiar_json(respuesta.text))


def analizar_progreso(usuario):
    progresos = usuario.progresos.all()[:10]
    historial = '\n'.join([
        f"- Fecha: {p.fecha}, Peso: {p.peso}kg, Observaciones: {p.observaciones}"
        for p in progresos
    ])

    prompt = f"""
    Eres un entrenador personal experto. Analiza el progreso del usuario y ajusta su plan.
    
    Datos del usuario:
    - Nombre: {usuario.username}
    - Objetivo: {usuario.objetivo or 'No especificado'}
    
    Historial de progreso:
    {historial if historial else 'Sin registros aún'}
    
    Responde SOLO con un JSON válido con esta estructura exacta:
    {{
        "analisis": "análisis detallado del progreso",
        "esta_progresando": true,
        "recomendacion": "recomendación principal",
        "ajustes_plan": "ajustes sugeridos al plan de entrenamiento",
        "ajustes_alimentacion": "ajustes sugeridos al plan de alimentación"
    }}
    """
    respuesta = cliente.models.generate_content(model=MODELO, contents=prompt)
    return json.loads(_limpiar_json(respuesta.text))


def chat_coach(usuario, mensaje):
    historial = usuario.conversaciones.filter(tipo='coach')[:5]
    contexto = '\n'.join([
        f"Usuario: {c.mensaje_usuario}\nCoach: {c.respuesta_ia}"
        for c in reversed(list(historial))
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
        campos_faltantes.append('condiciones médicas')
    if not usuario.alergias:
        campos_faltantes.append('alergias alimentarias')
    if not usuario.lesiones:
        campos_faltantes.append('lesiones o limitaciones físicas')
    if not usuario.restricciones_alimentarias:
        campos_faltantes.append('restricciones alimentarias')
    if not usuario.dias_entrenamiento:
        campos_faltantes.append('días de entrenamiento por semana')
    if not usuario.tiempo_sesion:
        campos_faltantes.append('tiempo por sesión')
    if not usuario.lugar_entrenamiento:
        campos_faltantes.append('lugar de entrenamiento')

    perfil_completo = f"""
    Datos del usuario:
    - Nombre: {usuario.username}
    - Edad: {usuario.edad or 'No especificada'}
    - Peso: {usuario.peso or 'No especificado'} kg
    - Altura: {usuario.altura or 'No especificada'} cm
    - Género: {usuario.genero or 'No especificado'}
    - Objetivo: {usuario.objetivo or 'No especificado'}
    - Objetivo de tiempo: {usuario.objetivo_tiempo or 'No especificado'}
    - Motivación: {usuario.motivacion or 'No especificada'}
    - Nivel de actividad: {usuario.nivel_actividad or 'No especificado'}
    - Días de entrenamiento: {usuario.dias_entrenamiento or 'No especificado'}
    - Tiempo por sesión: {usuario.tiempo_sesion or 'No especificado'} min
    - Lugar: {usuario.lugar_entrenamiento or 'No especificado'}
    - Tiene equipo: {'Sí' if usuario.tiene_equipo else 'No'}
    - Condiciones médicas: {usuario.condiciones_medicas or 'Ninguna'}
    - Alergias: {usuario.alergias or 'Ninguna'}
    - Lesiones: {usuario.lesiones or 'Ninguna'}
    - Restricciones alimentarias: {usuario.restricciones_alimentarias or 'Ninguna'}
    - Comidas por día: {usuario.comidas_por_dia or 'No especificado'}
    - Agua por día: {usuario.agua_por_dia or 'No especificado'} litros
    - Calidad del sueño: {usuario.calidad_sueno or 'No especificada'}
    - Nivel de estrés: {usuario.nivel_estres or 'No especificado'}
    """

    # ── Obtener plan de alimentación activo para contexto ─────
    plan_alimentacion_activo = usuario.planes_alimentacion.filter(activo=True).last()
    info_plan_alimentacion = ''
    if plan_alimentacion_activo:
        comidas = plan_alimentacion_activo.rutina_comidas.all()
        nombres_comidas = ', '.join([c.nombre for c in comidas])
        info_plan_alimentacion = f"Plan de alimentación activo con estas comidas: {nombres_comidas}"

    # ── Obtener plan de entrenamiento activo para contexto ────
    plan_entrenamiento_activo = usuario.planes_entrenamiento.filter(activo=True).last()
    info_plan_entrenamiento = ''
    if plan_entrenamiento_activo:
        ejercicios = plan_entrenamiento_activo.rutina_ejercicios.all()
        nombres_ejercicios = ', '.join([f"{e.nombre} ({e.grupo_muscular})" for e in ejercicios])
        info_plan_entrenamiento = f"Plan de entrenamiento activo con estos ejercicios: {nombres_ejercicios}"

    prompt = f"""
    Eres TrainerIA, un coach personal experto, empático y motivador.
    Responde en español de forma amigable y personalizada.
    
    {perfil_completo}
    
    Progreso reciente:
    {progreso_reciente if progreso_reciente else 'Sin registros aún'}
    
    Historial de conversación:
    {contexto if contexto else 'Primera conversación'}
    
    {info_plan_alimentacion if info_plan_alimentacion else 'El usuario no tiene plan de alimentación activo.'}
    {info_plan_entrenamiento if info_plan_entrenamiento else 'El usuario no tiene plan de entrenamiento activo.'}
    
    Campos del perfil que faltan completar:
    {', '.join(campos_faltantes) if campos_faltantes else 'Perfil completo'}
    
    Mensaje del usuario: {mensaje}
    
    INSTRUCCIONES IMPORTANTES:
    1. Si el usuario quiere modificar algún dato de su perfil, dile que con gusto lo actualizas
       y responde con un JSON al final así: {{"actualizar_perfil": {{"campo": "valor"}}}}
    2. Si hay campos faltantes y es una buena oportunidad, pregunta UNO solo de forma natural.
    3. Si el usuario menciona una condición médica, alergia o lesión nueva, actualiza su perfil.
    4. Responde de forma natural y motivadora. Máximo 3 párrafos.
    5. Si el usuario pide un plan, primero verifica que tenga el perfil básico completo.
    6. CRÍTICO: Si el usuario dice que NO le gusta, que no quiere, que le cae mal,
       o que quiere evitar CUALQUIER alimento o comida del plan actual,
       SIEMPRE debes regenerar el plan sin importar si es uno solo o varios alimentos.
       Actualiza primero las alergias o restricciones del perfil si aplica, y responde con este JSON al final:
       {{"regenerar_plan_alimentacion": true, "motivo": "razón del cambio"}}
       NO preguntes si quiere cambiar el plan — hazlo directamente.
    7. CRÍTICO: Si el usuario menciona que NO puede hacer, que le duele, que no le gusta,
       o que quiere evitar CUALQUIER ejercicio específico o tipo de movimiento,
       SIEMPRE debes regenerar el plan sin importar si es uno solo o varios ejercicios.
       Actualiza primero las lesiones del perfil si aplica, y responde con este JSON al final:
       {{"regenerar_plan_entrenamiento": true, "motivo": "razón del cambio"}}
       NO preguntes si quiere cambiar el plan — hazlo directamente.
    """

    respuesta = cliente.models.generate_content(model=MODELO, contents=prompt)
    texto = respuesta.text.strip()

    # ── Procesar actualización de perfil ──────────────────────
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

    # ── Procesar regeneración de plan de alimentación ─────────
    if '"regenerar_plan_alimentacion"' in texto:
        try:
            json_match = re.search(r'\{"regenerar_plan_alimentacion":\s*true[^}]*\}', texto)
            if json_match:
                texto = texto[:json_match.start()].strip()

                # Desactivar plan actual si existe
                if plan_alimentacion_activo:
                    plan_alimentacion_activo.activo = False
                    plan_alimentacion_activo.completado = True
                    plan_alimentacion_activo.save()

                # Generar nuevo plan con las preferencias actualizadas
                nuevo_plan_data = generar_plan_alimentacion(usuario)

                from .models import PlanAlimentacion, RutinaComida
                nuevo_plan = PlanAlimentacion.objects.create(
                    usuario=usuario,
                    calorias=nuevo_plan_data.get('calorias_diarias', 2000),
                    objetivo=nuevo_plan_data.get('objetivo', ''),
                    duracion_dias=nuevo_plan_data.get('duracion_dias', 30),
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
                        orden=index + 1
                    )
                texto += '\n\n✅ ¡Listo! Ya generé un nuevo plan de alimentación adaptado a tus preferencias.'
        except Exception:
            pass

    # ── Procesar regeneración de plan de entrenamiento ────────
    if '"regenerar_plan_entrenamiento"' in texto:
        try:
            json_match = re.search(r'\{"regenerar_plan_entrenamiento":\s*true[^}]*\}', texto)
            if json_match:
                texto = texto[:json_match.start()].strip()

                # Desactivar plan actual si existe
                if plan_entrenamiento_activo:
                    plan_entrenamiento_activo.activo = False
                    plan_entrenamiento_activo.completado = True
                    plan_entrenamiento_activo.save()

                # Generar nuevo plan con las limitaciones actualizadas
                nuevo_plan_data = generar_plan_entrenamiento(usuario)

                from .models import PlanEntrenamiento, RutinaEjercicio
                nuevo_plan = PlanEntrenamiento.objects.create(
                    usuario=usuario,
                    tipo_entrenamiento=nuevo_plan_data.get('tipo_entrenamiento', ''),
                    nivel=nuevo_plan_data.get('nivel', 'Principiante'),
                    duracion=nuevo_plan_data.get('duracion', 4),
                )
                for index, ejercicio in enumerate(nuevo_plan_data.get('ejercicios', [])):
                    RutinaEjercicio.objects.create(
                        plan=nuevo_plan,
                        nombre=ejercicio.get('nombre', ''),
                        grupo_muscular=ejercicio.get('grupo_muscular', ''),
                        series=ejercicio.get('series', 3),
                        repeticiones=ejercicio.get('repeticiones', 10),
                        descanso=ejercicio.get('descanso', '60 segundos'),
                        orden=index + 1
                    )
                texto += '\n\n✅ ¡Listo! Ya generé un nuevo plan de entrenamiento adaptado a tus limitaciones.'
        except Exception:
            pass

    return texto


def generar_descripcion_ejercicio(nombre, grupo_muscular):
    prompt = f"""
    Eres un entrenador personal experto. Describe el ejercicio en español.
    
    Ejercicio: {nombre}
    Grupo muscular: {grupo_muscular}
    
    Responde SOLO con un JSON válido con esta estructura exacta:
    {{
        "descripcion": "descripcion detallada del ejercicio",
        "musculos_secundarios": "músculos secundarios trabajados",
        "tecnica": "pasos para realizar el ejercicio correctamente",
        "errores_comunes": "errores comunes a evitar",
        "variaciones": "variaciones del ejercicio"
    }}
    """
    respuesta = cliente.models.generate_content(model=MODELO, contents=prompt)
    return json.loads(_limpiar_json(respuesta.text))