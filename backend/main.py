from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS
import jwt
import datetime
from passlib.context import CryptContext

app = FastAPI(title="API Puerto Logístico")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

SECRET_KEY = "clave_secreta_jwt"
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_postgres_db():
    return psycopg2.connect(dbname="puertodb", user="admin", password="adminpassword", host="puerto_postgres", port="5432")

def init_db():
    conn = get_postgres_db()
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS accesos (id SERIAL PRIMARY KEY, patente TEXT, anden TEXT, fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    
    # FORZAR REINICIO DE LA TABLA DE USUARIOS
    c.execute("DROP TABLE IF EXISTS usuarios")
    c.execute('''CREATE TABLE usuarios (id SERIAL PRIMARY KEY, username TEXT UNIQUE, password_hash TEXT, rol TEXT, nombre TEXT)''')
    
    # INSERTAR USUARIOS MANUALMENTE
    c.execute("INSERT INTO usuarios (username, password_hash, rol, nombre) VALUES (%s, %s, %s, %s)", ('admin', pwd_context.hash('Admin123'), 'Administrador', 'Administrador Central'))
    c.execute("INSERT INTO usuarios (username, password_hash, rol, nombre) VALUES (%s, %s, %s, %s)", ('joaquin', pwd_context.hash('Joaquin123'), 'Tablet', 'Joaquín Contreras'))
    
    conn.commit()
    conn.close()
    print("¡Usuarios creados exitosamente en PostgreSQL!")

init_db()

class LoginModel(BaseModel):
    usuario: str
    password: str

class RFIDModel(BaseModel):
    tag_rfid: str

@app.post("/api/login")
def login(data: LoginModel):
    conn = get_postgres_db()
    c = conn.cursor()
    c.execute("SELECT password_hash, rol, nombre FROM usuarios WHERE username = %s", (data.usuario,))
    user = c.fetchone()
    conn.close()

    if user and pwd_context.verify(data.password, user[0]):
        token = jwt.encode({"user": data.usuario, "rol": user[1], "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=2)}, SECRET_KEY, algorithm="HS256")
        return {"token": token, "rol": user[1], "nombre": user[2]}
    raise HTTPException(status_code=401, detail="Credenciales inválidas")

@app.post("/api/rfid")
def registrar_ingreso(data: RFIDModel):
    anden_asignado = "Andén B-4" if data.tag_rfid == "TAG-123" else "Andén C-1"
    return {"mensaje": "Acceso Registrado", "anden": anden_asignado}

@app.get("/api/historial")
def ver_historial():
    return [{"patente": "ABCD-12", "anden": "B-4", "fecha": "2026-10-30 10:00"}] # Simulado para mantener brevedad

from fastapi import HTTPException, Query
from pydantic import BaseModel
from typing import Optional

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