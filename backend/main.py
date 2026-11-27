from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import psycopg2
import jwt
import datetime
from passlib.context import CryptContext

app = FastAPI(title="API Puerto Logístico")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SECRET_KEY = "clave_secreta_jwt"
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def get_postgres_db():
    return psycopg2.connect(
        dbname="puertodb",
        user="admin",
        password="adminpassword",
        host="puerto_postgres",
        port="5432",
    )


def init_db():
    conn = get_postgres_db()
    c = conn.cursor()
    c.execute("""
        CREATE TABLE IF NOT EXISTS accesos (
            id SERIAL PRIMARY KEY,
            patente TEXT,
            anden TEXT,
            transportista TEXT DEFAULT 'Transportes Pacífico',
            contenedor TEXT DEFAULT 'MSKU-482910',
            tramite TEXT DEFAULT 'Ingreso',
            fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    c.execute("ALTER TABLE accesos ADD COLUMN IF NOT EXISTS transportista TEXT DEFAULT 'Transportes Pacífico';")
    c.execute("ALTER TABLE accesos ADD COLUMN IF NOT EXISTS contenedor TEXT DEFAULT 'MSKU-482910';")
    c.execute("ALTER TABLE accesos ADD COLUMN IF NOT EXISTS tramite TEXT DEFAULT 'Ingreso';")

    c.execute("""
        CREATE TABLE IF NOT EXISTS usuarios (
            id SERIAL PRIMARY KEY,
            username TEXT UNIQUE,
            password_hash TEXT,
            rol TEXT,
            nombre TEXT,
            equipo_asignado TEXT DEFAULT 'Sin asignar',
            licencia_activa BOOLEAN DEFAULT TRUE,
            motivo_bloqueo TEXT DEFAULT ''
        )
    """)
    c.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS equipo_asignado TEXT DEFAULT 'Sin asignar';")
    c.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS licencia_activa BOOLEAN DEFAULT TRUE;")
    c.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS motivo_bloqueo TEXT DEFAULT '';")

    c.execute(
        """
        INSERT INTO usuarios (username, password_hash, rol, nombre, equipo_asignado, licencia_activa)
        VALUES (%s, %s, %s, %s, %s, TRUE)
        ON CONFLICT (username) DO NOTHING
        """,
        ("admin", pwd_context.hash("Admin123"), "Administrador", "Administrador Central", "Central TOS"),
    )
    c.execute(
        """
        INSERT INTO usuarios (username, password_hash, rol, nombre, equipo_asignado, licencia_activa)
        VALUES (%s, %s, %s, %s, %s, TRUE)
        ON CONFLICT (username) DO NOTHING
        """,
        ("joaquin", pwd_context.hash("Joaquin123"), "Tablet", "Joaquín Contreras", "Grúa RTG-04"),
    )

    c.execute("""
        CREATE TABLE IF NOT EXISTS maniobras_grua (
            id SERIAL PRIMARY KEY,
            grua_id TEXT NOT NULL,
            operador TEXT NOT NULL,
            contenedor TEXT NOT NULL,
            origen TEXT NOT NULL,
            destino TEXT NOT NULL,
            duracion_seg INT NOT NULL,
            origen_sync TEXT DEFAULT 'Online',
            fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.commit()
    conn.close()


init_db()


class LoginModel(BaseModel):
    usuario: str
    password: str


class RFIDModel(BaseModel):
    tag_rfid: str


class AccesoCreate(BaseModel):
    patente: str
    anden: str
    transportista: Optional[str] = "Transportes Pacífico"
    contenedor: Optional[str] = "MSKU-482910"
    tramite: Optional[str] = "Ingreso"


class PerfilAdminUpdate(BaseModel):
    usuario: str
    nueva_password: str


class UsuarioCreate(BaseModel):
    username: str
    password: str
    rol: str
    nombre: str
    equipo_asignado: Optional[str] = "Grúa RTG-05"


class LicenciaUpdate(BaseModel):
    licencia_activa: bool
    motivo_bloqueo: Optional[str] = ""


class ManiobraIn(BaseModel):
    grua_id: str
    operador: str
    contenedor: str
    origen: str
    destino: str
    duracion_seg: int
    origen_sync: Optional[str] = "Online"


class ReporteDispositivoIn(BaseModel):
    registro_id: str
    dispositivo: str
    metrica: str
    valor: str
    severidad: str
    descripcion: Optional[str] = ""
    fecha_registro: str


@app.get("/api/estado-sistema")
def estado_sistema():
    pg_ok = False
    try:
        conn = get_postgres_db()
        with conn.cursor() as cur:
            cur.execute("SELECT 1;")
        conn.close()
        pg_ok = True
    except Exception:
        pg_ok = False

    return {
        "fastapi": True,
        "postgres": pg_ok,
        "influx": True,
        "timestamp": datetime.datetime.utcnow().isoformat(),
    }


@app.post("/api/login")
def login(data: LoginModel):
    conn = get_postgres_db()
    c = conn.cursor()
    c.execute(
        """
        SELECT password_hash, rol, nombre, COALESCE(licencia_activa, TRUE), COALESCE(motivo_bloqueo, '')
        FROM usuarios WHERE username = %s
        """,
        (data.usuario,),
    )
    user = c.fetchone()
    conn.close()

    if user and pwd_context.verify(data.password, user[0]):
        if not user[3]:
            motivo = user[4] if user[4] else "Licencia de terminal cancelada por reporte de robo."
            raise HTTPException(
                status_code=403,
                detail=f"ACCESO DENEGADO: {motivo} Contacte a Central TOS.",
            )

        token = jwt.encode(
            {
                "user": data.usuario,
                "rol": user[1],
                "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=2),
            },
            SECRET_KEY,
            algorithm="HS256",
        )
        return {
            "token": token,
            "username": data.usuario,
            "rol": user[1],
            "nombre": user[2],
        }
    raise HTTPException(status_code=401, detail="Usuario o contraseña incorrectos.")


@app.get("/api/usuarios")
def listar_usuarios():
    conn = get_postgres_db()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, username, rol, nombre, COALESCE(equipo_asignado, 'Sin asignar'),
                       COALESCE(licencia_activa, TRUE), COALESCE(motivo_bloqueo, '')
                FROM usuarios
                ORDER BY id ASC;
            """)
            filas = cur.fetchall()
        return [
            {
                "id": f[0],
                "username": f[1],
                "rol": f[2],
                "nombre": f[3],
                "equipo_asignado": f[4],
                "licencia_activa": f[5],
                "motivo_bloqueo": f[6],
            }
            for f in filas
        ]
    finally:
        conn.close()


@app.post("/api/usuarios")
def crear_usuario(nuevo: UsuarioCreate):
    username_limpio = nuevo.username.strip().lower()
    if not username_limpio or not nuevo.password or not nuevo.nombre.strip():
        raise HTTPException(status_code=400, detail="Todos los campos son obligatorios.")

    conn = get_postgres_db()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM usuarios WHERE username = %s;", (username_limpio,))
            if cur.fetchone():
                raise HTTPException(status_code=400, detail="El nombre de usuario ya existe.")

            cur.execute(
                """
                INSERT INTO usuarios (username, password_hash, rol, nombre, equipo_asignado, licencia_activa)
                VALUES (%s, %s, %s, %s, %s, TRUE)
                RETURNING id;
                """,
                (
                    username_limpio,
                    pwd_context.hash(nuevo.password),
                    nuevo.rol,
                    nuevo.nombre.strip(),
                    nuevo.equipo_asignado or "Sin asignar",
                ),
            )
            nuevo_id = cur.fetchone()[0]
        conn.commit()
        return {"id": nuevo_id, "mensaje": "Perfil de trabajador creado correctamente"}
    finally:
        conn.close()


@app.put("/api/usuarios/{usuario_id}/licencia")
def actualizar_licencia_usuario(usuario_id: int, datos: LicenciaUpdate):
    conn = get_postgres_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT username, nombre, rol, equipo_asignado FROM usuarios WHERE id = %s;",
                (usuario_id,),
            )
            usuario = cur.fetchone()
            if not usuario:
                raise HTTPException(status_code=404, detail="Trabajador no encontrado.")

            if usuario[0] == "admin" and not datos.licencia_activa:
                raise HTTPException(
                    status_code=400,
                    detail="No se puede revocar la licencia del administrador principal.",
                )

            motivo = datos.motivo_bloqueo or (
                "Tablet reportada como robada / extraviada" if not datos.licencia_activa else ""
            )

            cur.execute(
                """
                UPDATE usuarios
                SET licencia_activa = %s, motivo_bloqueo = %s
                WHERE id = %s;
                """,
                (datos.licencia_activa, motivo, usuario_id),
            )

            if not datos.licencia_activa:
                crear_tabla_reportes(conn)
                ahora = datetime.datetime.now()
                reg_id = f"SEG-LIC-{usuario_id}-{int(ahora.timestamp())}"
                cur.execute(
                    """
                    INSERT INTO reportes_dispositivos
                    (registro_id, dispositivo, metrica, valor, severidad, descripcion, fecha_registro)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (registro_id) DO NOTHING;
                    """,
                    (
                        reg_id,
                        f"Tablet_{usuario[1].replace(' ', '_')}",
                        "licencia_terminal",
                        "REVOCADA_ROBO",
                        "grave",
                        f"Licencia cancelada por robo para {usuario[1]} ({usuario[3]})",
                        ahora.strftime("%Y-%m-%d %H:%M:%S"),
                    ),
                )

        conn.commit()
        return {
            "mensaje": "Licencia cancelada y terminal bloqueada"
            if not datos.licencia_activa
            else "Licencia reactivada correctamente"
        }
    finally:
        conn.close()


@app.get("/api/usuarios/{username}/estado-licencia")
def estado_licencia_usuario(username: str):
    conn = get_postgres_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT COALESCE(licencia_activa, TRUE), COALESCE(motivo_bloqueo, '')
                FROM usuarios WHERE username = %s;
                """,
                (username,),
            )
            fila = cur.fetchone()
        if not fila:
            return {"licencia_activa": False, "motivo_bloqueo": "Usuario eliminado del sistema."}
        return {"licencia_activa": fila[0], "motivo_bloqueo": fila[1]}
    finally:
        conn.close()


@app.put("/api/admin/perfil")
def actualizar_perfil_admin(datos: PerfilAdminUpdate):
    conn = get_postgres_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE usuarios SET username = %s, password_hash = %s WHERE rol = 'Administrador' AND id = 1;",
                (datos.usuario, pwd_context.hash(datos.nueva_password)),
            )
        conn.commit()
        return {"mensaje": "Perfil actualizado correctamente"}
    finally:
        conn.close()


@app.post("/api/rfid")
def registrar_rfid(data: RFIDModel):
    conn = get_postgres_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO accesos (patente, anden, transportista, contenedor, tramite) VALUES (%s, %s, %s, %s, %s) RETURNING id;",
                (data.tag_rfid, "Andén B-4", "Logística Sur", "MSKU-742918", "Ingreso"),
            )
            nuevo_id = cur.fetchone()[0]
        conn.commit()
        return {"id": nuevo_id, "patente": data.tag_rfid, "anden": "Andén B-4"}
    finally:
        conn.close()


@app.post("/api/accesos")
def crear_acceso(acceso: AccesoCreate):
    conn = get_postgres_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO accesos (patente, anden, transportista, contenedor, tramite)
                VALUES (%s, %s, %s, %s, %s) RETURNING id, fecha;
                """,
                (acceso.patente, acceso.anden, acceso.transportista, acceso.contenedor, acceso.tramite),
            )
            row = cur.fetchone()
        conn.commit()
        return {
            "id": row[0],
            "patente": acceso.patente,
            "anden": acceso.anden,
            "transportista": acceso.transportista,
            "contenedor": acceso.contenedor,
            "tramite": acceso.tramite,
            "fecha": row[1].isoformat() if row[1] else "",
        }
    finally:
        conn.close()


@app.get("/api/accesos")
def listar_accesos():
    conn = get_postgres_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, patente, anden, COALESCE(transportista, 'Logística Portuaria'),
                       COALESCE(contenedor, 'MSKU-482910'), COALESCE(tramite, 'Ingreso'), fecha
                FROM accesos
                ORDER BY fecha DESC
                LIMIT 25;
                """
            )
            filas = cur.fetchall()
        return [
            {
                "id": f[0],
                "patente": f[1],
                "anden": f[2],
                "transportista": f[3],
                "contenedor": f[4],
                "tramite": f[5],
                "fecha": f[6].strftime("%H:%M:%S") if f[6] else "",
            }
            for f in filas
        ]
    finally:
        conn.close()


@app.post("/api/maniobras")
def registrar_maniobra(m: ManiobraIn):
    conn = get_postgres_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO maniobras_grua (grua_id, operador, contenedor, origen, destino, duracion_seg, origen_sync)
                VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id;
                """,
                (m.grua_id, m.operador, m.contenedor, m.origen, m.destino, m.duracion_seg, m.origen_sync),
            )
            nuevo_id = cur.fetchone()[0]
        conn.commit()
        return {"id": nuevo_id, "mensaje": "Maniobra registrada"}
    finally:
        conn.close()


@app.get("/api/maniobras")
def listar_maniobras():
    conn = get_postgres_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, grua_id, operador, contenedor, origen, destino, duracion_seg, origen_sync, fecha
                FROM maniobras_grua
                ORDER BY fecha DESC
                LIMIT 20;
                """
            )
            filas = cur.fetchall()
        return [
            {
                "id": f[0],
                "grua_id": f[1],
                "operador": f[2],
                "contenedor": f[3],
                "origen": f[4],
                "destino": f[5],
                "duracion_seg": f[6],
                "origen_sync": f[7],
                "fecha": f[8].strftime("%Y-%m-%d %H:%M:%S") if f[8] else "",
            }
            for f in filas
        ]
    finally:
        conn.close()


def crear_tabla_reportes(conn):
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS reportes_dispositivos (
                id SERIAL PRIMARY KEY,
                registro_id VARCHAR(120) UNIQUE NOT NULL,
                dispositivo VARCHAR(100) NOT NULL,
                metrica VARCHAR(100) NOT NULL,
                valor VARCHAR(50) NOT NULL,
                severidad VARCHAR(20) NOT NULL,
                descripcion TEXT,
                estado VARCHAR(20) DEFAULT 'pendiente',
                fecha_registro TIMESTAMP NOT NULL,
                fecha_reporte TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        cur.execute("ALTER TABLE reportes_dispositivos ADD COLUMN IF NOT EXISTS estado VARCHAR(20) DEFAULT 'pendiente';")
        muestras = [
            ("SEED-2024-02-1", "Antena_RFID_Norte", "tag_leido", "ERROR_LECTURA_RFID", "grave", "Falla lectura pórtico", "2024-02-14 09:20:00"),
            ("SEED-2024-02-2", "Sensor_Temp_Reefer", "temperatura_c", "-5 °C", "leve", "Variación térmica", "2024-02-21 15:10:00"),
            ("SEED-2024-05-1", "Telemetria_Grua_04", "rpm_motor", "2080 RPM", "grave", "Sobre-revolución motor", "2024-05-11 11:45:00"),
            ("SEED-2024-08-1", "Camara_IP_Acceso", "ancho_banda_mbps", "14 Mbps", "leve", "Caída de ancho de banda", "2024-08-19 16:30:00"),
            ("SEED-2024-11-1", "Sensor_Temp_Reefer", "temperatura_c", "+4 °C", "grave", "Ruptura cadena de frío", "2024-11-08 07:50:00"),
            ("SEED-2024-11-2", "Antena_RFID_Norte", "tag_leido", "SEÑAL_DEBIL_TAG", "leve", "Atenuación RFID", "2024-11-23 18:15:00"),
            ("SEED-2025-01-1", "Telemetria_Grua_04", "rpm_motor", "1790 RPM", "leve", "Carga elevada", "2025-01-17 10:05:00"),
            ("SEED-2025-03-1", "Camara_IP_Acceso", "ancho_banda_mbps", "4 Mbps", "grave", "Pérdida de paquetes", "2025-03-12 13:40:00"),
            ("SEED-2025-03-2", "Sensor_Temp_Reefer", "temperatura_c", "-6 °C", "leve", "Desviación leve", "2025-03-25 09:12:00"),
            ("SEED-2025-06-1", "Antena_RFID_Norte", "tag_leido", "ERROR_LECTURA_RFID", "grave", "Tag ilegible", "2025-06-09 14:22:00"),
            ("SEED-2025-09-1", "Telemetria_Grua_04", "rpm_motor", "2120 RPM", "grave", "Pico de RPM", "2025-09-18 17:00:00"),
            ("SEED-2025-09-2", "Camara_IP_Acceso", "ancho_banda_mbps", "16 Mbps", "leve", "Latencia en enlace", "2025-09-27 12:18:00"),
            ("SEED-2025-12-1", "Sensor_Temp_Reefer", "temperatura_c", "+5 °C", "grave", "Alarma térmica contenedor", "2025-12-04 08:35:00"),
            ("SEED-2026-01-1", "Antena_RFID_Norte", "tag_leido", "SEÑAL_DEBIL_TAG", "leve", "Interferencia en pórtico", "2026-01-15 10:40:00"),
            ("SEED-2026-03-1", "Sensor_Temp_Reefer", "temperatura_c", "+3 °C", "grave", "Alarma temperatura Reefer", "2026-03-19 14:55:00"),
            ("SEED-2026-03-2", "Telemetria_Grua_04", "rpm_motor", "1760 RPM", "leve", "RPM sobre umbral normal", "2026-03-28 11:10:00"),
            ("SEED-2026-06-1", "Camara_IP_Acceso", "ancho_banda_mbps", "3 Mbps", "grave", "Enlace degradado", "2026-06-14 16:05:00"),
            ("SEED-2026-08-1", "Antena_RFID_Norte", "tag_leido", "ERROR_LECTURA_RFID", "grave", "Fallo lector Norte", "2026-08-22 09:30:00"),
            ("SEED-2026-08-2", "Sensor_Temp_Reefer", "temperatura_c", "-5 °C", "leve", "Fluctuación térmica", "2026-08-29 19:20:00"),
            ("SEED-2026-10-1", "Telemetria_Grua_04", "rpm_motor", "2040 RPM", "grave", "Exceso de RPM en izaje", "2026-10-11 15:45:00"),
            ("SEED-2026-11-1", "Camara_IP_Acceso", "ancho_banda_mbps", "15 Mbps", "leve", "Ancho de banda reducido", "2026-11-05 12:00:00"),
        ]
        for m in muestras:
            cur.execute("""
                INSERT INTO reportes_dispositivos
                (registro_id, dispositivo, metrica, valor, severidad, descripcion, fecha_registro)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (registro_id) DO NOTHING;
            """, m)
    conn.commit()


@app.post("/api/reportes-dispositivos")
def crear_reporte_dispositivo(reporte: ReporteDispositivoIn):
    conn = get_postgres_db()
    try:
        crear_tabla_reportes(conn)
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id FROM reportes_dispositivos WHERE registro_id = %s",
                (reporte.registro_id,),
            )
            if cur.fetchone():
                return {
                    "ya_reportado": True,
                    "mensaje": "El problema ya ha sido reportado",
                }

            cur.execute(
                """
                INSERT INTO reportes_dispositivos
                (registro_id, dispositivo, metrica, valor, severidad, descripcion, fecha_registro)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                RETURNING id;
                """,
                (
                    reporte.registro_id,
                    reporte.dispositivo,
                    reporte.metrica,
                    reporte.valor,
                    reporte.severidad,
                    reporte.descripcion,
                    reporte.fecha_registro,
                ),
            )
            nuevo_id = cur.fetchone()[0]
        conn.commit()
        return {
            "ya_reportado": False,
            "id": nuevo_id,
            "mensaje": "Reporte agregado al Panel de Alertas",
        }
    finally:
        conn.close()


@app.put("/api/reportes-dispositivos/{reporte_id}/resolver")
def resolver_reporte_dispositivo(reporte_id: int):
    conn = get_postgres_db()
    try:
        crear_tabla_reportes(conn)
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE reportes_dispositivos SET estado = 'resuelto' WHERE id = %s;",
                (reporte_id,),
            )
        conn.commit()
        return {"mensaje": "Reporte marcado como resuelto"}
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
                       descripcion, COALESCE(estado, 'pendiente'), fecha_registro, fecha_reporte
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
                "estado": f[7],
                "fecha_registro": f[8].isoformat() if f[8] else "",
                "fecha_reporte": f[9].isoformat() if f[9] else "",
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

            cur.execute(
                """
                SELECT
                    EXTRACT(MONTH FROM fecha_registro)::int AS mes,
                    SUM(CASE WHEN severidad = 'grave' THEN 1 ELSE 0 END) AS graves,
                    SUM(CASE WHEN severidad = 'leve' THEN 1 ELSE 0 END) AS leves
                FROM reportes_dispositivos
                WHERE EXTRACT(YEAR FROM fecha_registro)::int = %s
                GROUP BY mes
                ORDER BY mes;
                """,
                (anio,),
            )
            resultados = {r[0]: {"graves": r[1], "leves": r[2]} for r in cur.fetchall()}

        meses = []
        for m in range(1, 13):
            datos = resultados.get(m, {"graves": 0, "leves": 0})
            meses.append(
                {
                    "mes": m,
                    "graves": datos["graves"],
                    "leves": datos["leves"],
                    "total": datos["graves"] + datos["leves"],
                }
            )

        return {
            "anio": anio,
            "anios_disponibles": sorted(list(set(anios_disponibles)), reverse=True),
            "meses": meses,
        }
    finally:
        conn.close()