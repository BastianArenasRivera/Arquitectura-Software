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
    return psycopg2.connect(dbname="puertodb", user="admin", password="adminpassword", host="127.0.0.1", port="5433") # Cambia el puerto si usas el 5433

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