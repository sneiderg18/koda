import google.generativeai as genai
import os
import json
from django.conf import settings

genai.configure(api_key=os.getenv('GEMINI_API_KEY'))
modelo = genai.GenerativeModel('gemini-1.5-pro')


def generar_plan_entrenamiento(usuario):
    prompt = f"""
    Eres un entrenador personal experto. Genera un plan de entrenamiento personalizado en español.
    
    Datos del usuario:
    - Nombre: {usuario.username}
    - Edad: {usuario.edad or 'No especificada'}
    - Peso: {usuario.peso or 'No especificado'} kg
    - Altura: {usuario.altura or 'No especificada'} cm
    - Objetivo: {usuario.objetivo or 'No especificado'}
    
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
    respuesta = modelo.generate_content(prompt)
    texto = respuesta.text.strip()
    if texto.startswith('```'):
        texto = texto.split('```')[1]
        if texto.startswith('json'):
            texto = texto[4:]
    return json.loads(texto.strip())


def generar_plan_alimentacion(usuario):
    prompt = f"""
    Eres un nutricionista experto. Genera un plan de alimentación personalizado en español.
    
    Datos del usuario:
    - Nombre: {usuario.username}
    - Edad: {usuario.edad or 'No especificada'}
    - Peso: {usuario.peso or 'No especificado'} kg
    - Altura: {usuario.altura or 'No especificada'} cm
    - Objetivo: {usuario.objetivo or 'No especificado'}
    
    Responde SOLO con un JSON válido con esta estructura exacta:
    {{
        "calorias_diarias": numero,
        "objetivo": "objetivo nutricional",
        "descripcion": "descripcion general del plan",
        "comidas": [
            {{
                "nombre": "nombre de la comida",
                "momento": "Desayuno/Almuerzo/Cena/Merienda",
                "calorias": numero,
                "proteinas": numero,
                "carbohidratos": numero,
                "grasas": numero,
                "descripcion": "descripcion de la comida"
            }}
        ]
    }}
    """
    respuesta = modelo.generate_content(prompt)
    texto = respuesta.text.strip()
    if texto.startswith('```'):
        texto = texto.split('```')[1]
        if texto.startswith('json'):
            texto = texto[4:]
    return json.loads(texto.strip())


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
        "esta_progresando": true/false,
        "recomendacion": "recomendación principal",
        "ajustes_plan": "ajustes sugeridos al plan de entrenamiento",
        "ajustes_alimentacion": "ajustes sugeridos al plan de alimentación"
    }}
    """
    respuesta = modelo.generate_content(prompt)
    texto = respuesta.text.strip()
    if texto.startswith('```'):
        texto = texto.split('```')[1]
        if texto.startswith('json'):
            texto = texto[4:]
    return json.loads(texto.strip())


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

    prompt = f"""
    Eres un coach personal experto y motivador llamado "TrainerIA". 
    Responde en español de forma amigable, profesional y personalizada.
    
    Información del usuario:
    - Nombre: {usuario.username}
    - Objetivo: {usuario.objetivo or 'No especificado'}
    - Peso actual: {usuario.peso or 'No especificado'} kg
    - Altura: {usuario.altura or 'No especificada'} cm
    
    Progreso reciente:
    {progreso_reciente if progreso_reciente else 'Sin registros aún'}
    
    Historial de conversación:
    {contexto if contexto else 'Primera conversación'}
    
    Mensaje del usuario: {mensaje}
    
    Responde de forma natural, motivadora y útil. Máximo 3 párrafos.
    """
    respuesta = modelo.generate_content(prompt)
    return respuesta.text.strip()


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
    respuesta = modelo.generate_content(prompt)
    texto = respuesta.text.strip()
    if texto.startswith('```'):
        texto = texto.split('```')[1]
        if texto.startswith('json'):
            texto = texto[4:]
    return json.loads(texto.strip())