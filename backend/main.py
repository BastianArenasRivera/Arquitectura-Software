from fastapi import HTTPException, Query
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

def crear_tabla_reportes(conn):
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS reportes_dispositivos (
                id SERIAL PRIMARY KEY,
                registro_id VARCHAR(120) UNIQUE NOT NULL,
                dispositivo VARCHAR(100) NOT NULL,
                metrica VARCHAR(100) NOT NULL,
                valor VARCHAR(50) NOT NULL,
                severidad VARCHAR(20) NOT NULL, -- 'grave' o 'leve'
                descripcion TEXT,
                fecha_registro TIMESTAMP NOT NULL,
                fecha_reporte TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
    conn.commit()

class ReporteDispositivoIn(BaseModel):
    registro_id: str
    dispositivo: str
    metrica: str
    valor: str
    severidad: str  
    descripcion: Optional[str] = ""
    fecha_registro: str

@app.post("/api/reportes-dispositivos")
def crear_reporte_dispositivo(reporte: ReporteDispositivoIn):
    conn = get_postgres_db()
    try:
        crear_tabla_reportes(conn)
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id FROM reportes_dispositivos WHERE registro_id = %s",
                (reporte.registro_id,)
            )
            if cur.fetchone():
                return {
                    "ya_reportado": True,
                    "mensaje": "El problema ya ha sido reportado"
                }

            cur.execute("""
                INSERT INTO reportes_dispositivos
                (registro_id, dispositivo, metrica, valor, severidad, descripcion, fecha_registro)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                RETURNING id;
            """, (
                reporte.registro_id,
                reporte.dispositivo,
                reporte.metrica,
                reporte.valor,
                reporte.severidad,
                reporte.descripcion,
                reporte.fecha_registro
            ))
            nuevo_id = cur.fetchone()[0]
        conn.commit()
        return {
            "ya_reportado": False,
            "id": nuevo_id,
            "mensaje": "Reporte agregado al Panel de Alertas"
        }
    finally:
        conn.close()

@app.get("/api/reportes-dispositivos")
def listar_reportes_dispositivos():
    conn = get_postgres_db()
    try:
        crear_tabla_reportes(conn)
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, registro_id, dispositivo, metrica, valor, severidad,
                       descripcion, fecha_registro, fecha_reporte
                FROM reportes_dispositivos
                ORDER BY fecha_reporte DESC;
            """)
            filas = cur.fetchall()
        return [
            {
                "id": f[0],
                "registro_id": f[1],
                "dispositivo": f[2],
                "metrica": f[3],
                "valor": f[4],
                "severidad": f[5],
                "descripcion": f[6],
                "fecha_registro": f[7].isoformat() if f[7] else "",
                "fecha_reporte": f[8].isoformat() if f[8] else "",
            }
            for f in filas
        ]
    finally:
        conn.close()

@app.get("/api/reportes-dispositivos/resumen-anual")
def resumen_anual_reportes(anio: int = Query(default=2026)):
    conn = get_postgres_db()
    try:
        crear_tabla_reportes(conn)
        with conn.cursor() as cur:
            cur.execute("""
                SELECT DISTINCT EXTRACT(YEAR FROM fecha_registro)::int AS y
                FROM reportes_dispositivos
                ORDER BY y DESC;
            """)
            anios_disponibles = [r[0] for r in cur.fetchall()]
            if anio not in anios_disponibles:
                anios_disponibles.insert(0, anio)

            cur.execute("""
                SELECT
                    EXTRACT(MONTH FROM fecha_registro)::int AS mes,
                    SUM(CASE WHEN severidad = 'grave' THEN 1 ELSE 0 END) AS graves,
                    SUM(CASE WHEN severidad = 'leve' THEN 1 ELSE 0 END) AS leves
                FROM reportes_dispositivos
                WHERE EXTRACT(YEAR FROM fecha_registro)::int = %s
                GROUP BY mes
                ORDER BY mes;
            """, (anio,))
            resultados = {r[0]: {"graves": r[1], "leves": r[2]} for r in cur.fetchall()}

        meses = []
        for m in range(1, 13):
            datos = resultados.get(m, {"graves": 0, "leves": 0})
            meses.append({
                "mes": m,
                "graves": datos["graves"],
                "leves": datos["leves"],
                "total": datos["graves"] + datos["leves"]
            })

        return {
            "anio": anio,
            "anios_disponibles": sorted(list(set(anios_disponibles)), reverse=True),
            "meses": meses
        }
    finally:
        conn.close()