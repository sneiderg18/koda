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

    prompt = f"""
    Eres TrainerIA, un coach personal experto, empático y motivador.
    Responde en español de forma amigable y personalizada.
    
    {perfil_completo}
    
    Progreso reciente:
    {progreso_reciente if progreso_reciente else 'Sin registros aún'}
    
    Historial de conversación:
    {contexto if contexto else 'Primera conversación'}
    
    Campos del perfil que faltan completar:
    {', '.join(campos_faltantes) if campos_faltantes else 'Perfil completo'}
    
    Mensaje del usuario: {mensaje}
    
    INSTRUCCIONES IMPORTANTES:
    1. Si el usuario quiere modificar algún dato de su perfil, dile que con gusto lo actualizas
       y responde con un JSON al final así: {{"actualizar_perfil": {{"campo": "valor"}}}}
    2. Si hay campos faltantes y es una buena oportunidad, pregunta UNO solo de forma natural
    3. Si el usuario menciona una condición médica, alergia o lesión nueva, actualiza su perfil
    4. Responde de forma natural y motivadora. Máximo 3 párrafos.
    5. Si el usuario pide un plan, primero verifica que tenga el perfil básico completo
    """

    respuesta = cliente.models.generate_content(model=MODELO, contents=prompt)
    texto = respuesta.text.strip()

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