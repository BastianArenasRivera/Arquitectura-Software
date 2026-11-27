// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../config/api_config.dart';

// Terminal embarcado en cabina de grúa con detección offline automática y revocación remota por robo
class TabletGruaView extends StatefulWidget {
  final String nombreOperador;
  final String username;

  const TabletGruaView({
    super.key,
    this.nombreOperador = 'Joaquín Contreras',
    this.username = 'joaquin',
  });

  @override
  State<TabletGruaView> createState() => _TabletGruaViewState();
}

class _TabletGruaViewState extends State<TabletGruaView> {
  static const String _storageKey = 'cola_maniobras_offline';

  bool _isOnline = true;
  bool _sincronizando = false;
  bool _licenciaBloqueada = false;
  int _etapaManiobra = 0; // 0: Recogida, 1: Descarga en andén, 2: Completada
  int _indiceTarea = 0;
  DateTime _inicioManiobra = DateTime.now();
  int _ultimaDuracionSeg = 0;

  List _colaOffline = [];
  StreamSubscription<html.Event>? _subOnline;
  StreamSubscription<html.Event>? _subOffline;
  Timer? _heartbeatTimer;

  // Órdenes de maniobra asignadas al operador
  final List _tareasAsignadas = const [
    {
      'contenedor': 'MSKU 742918-0',
      'tipo': "40' High Cube Reefer (-18°C)",
      'peso': '24.5 TON',
      'sello': 'ML-742918',
      'origen': 'Bloque A • Bahía 01 • Nivel 2',
      'destino': 'Andén B-4 (Camión ABCD-12)',
      'alerta': 'CARGA REFRIGERADA ACTIVA • MANTENER NIVELACIÓN',
    },
    {
      'contenedor': 'MSCU 901234-5',
      'tipo': "40' High Cube Dry",
      'peso': '21.8 TON',
      'sello': 'SC-901234',
      'origen': 'Bloque B • Bahía 01 • Nivel 1',
      'destino': 'Andén B-2 (Camión KLRW-88)',
      'alerta': 'EXPORTACIÓN PRIORITARIA • BUQUE MSC ORION',
    },
    {
      'contenedor': 'HLCU 553821-9',
      'tipo': "20' Heavy Duty",
      'peso': '27.2 TON',
      'sello': 'HL-553821',
      'origen': 'Bloque B • Bahía 02 • Nivel 3',
      'destino': 'Andén C-1 (Camión PGTZ-45)',
      'alerta': 'CARGA PESADA • VELOCIDAD DE IZAJE REDUCIDA',
    },
  ];

  @override
  void initState() {
    super.initState();
    _cargarColaLocal();
    _isOnline = html.window.navigator.onLine ?? true;

    // Escucha eventos nativos del navegador al desconectarse o reconectarse internet
    _subOffline = html.window.onOffline.listen((_) {
      _actualizarEstadoConexion(false);
    });
    _subOnline = html.window.onOnline.listen((_) {
      _verificarConexionReal();
    });

    // Ejecuta un latido cada 3 segundos para validar conexión real y estado de licencia
    _verificarConexionReal();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _verificarConexionReal(),
    );
  }

  @override
  void dispose() {
    _subOffline?.cancel();
    _subOnline?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  // Lee maniobras pendientes guardadas en localStorage
  void _cargarColaLocal() {
    final guardado = html.window.localStorage[_storageKey];
    if (guardado != null && guardado.isNotEmpty) {
      try {
        _colaOffline = List.from(jsonDecode(guardado));
      } catch (_) {
        _colaOffline = [];
      }
    }
  }

  // Persiste la cola offline en localStorage
  void _guardarColaLocal() {
    html.window.localStorage[_storageKey] = jsonEncode(_colaOffline);
  }

  // Comprueba conectividad con FastAPI y consulta si la licencia sigue activa
  Future<void> _verificarConexionReal() async {
    if (_licenciaBloqueada) return;

    if (html.window.navigator.onLine == false) {
      _actualizarEstadoConexion(false);
      return;
    }

    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/api/estado-sistema'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        _actualizarEstadoConexion(true);
        await _verificarEstadoLicencia();
      } else {
        _actualizarEstadoConexion(false);
      }
    } catch (_) {
      _actualizarEstadoConexion(false);
    }
  }

  // Verifica en PostgreSQL si el administrador revocó la licencia de esta tablet por robo
  Future<void> _verificarEstadoLicencia() async {
    if (_licenciaBloqueada) return;
    try {
      final res = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/usuarios/${widget.username}/estado-licencia',
            ),
          )
          .timeout(const Duration(seconds: 2));

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        if (data['licencia_activa'] == false) {
          _ejecutarBloqueoPorRobo(
            data['motivo_bloqueo'] ??
                'Licencia cancelada por Central TOS debido a reporte de robo.',
          );
        }
      }
    } catch (_) {}
  }

  // Borra datos locales, bloquea la interfaz y cierra sesión inmediatamente
  void _ejecutarBloqueoPorRobo(String motivo) {
    if (_licenciaBloqueada || !mounted) return;
    _heartbeatTimer?.cancel();
    html.window.localStorage.remove(_storageKey);

    setState(() {
      _licenciaBloqueada = true;
      _colaOffline.clear();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.gpp_bad, color: Colors.redAccent, size: 32),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'TERMINAL BLOQUEADA POR SEGURIDAD',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'La licencia de esta tablet fue revocada por el Administrador.\n\nMotivo: $motivo\n\nLos datos locales han sido eliminados y la sesión se cerrará.',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const SelectorView()),
                (route) => false,
              );
            },
            child: const Text('CERRAR TERMINAL'),
          ),
        ],
      ),
    );
  }

  // Actualiza el indicador Online/Offline y dispara la sincronización al recuperar señal
  void _actualizarEstadoConexion(bool conectado) {
    if (!mounted) return;
    final bool estabaDesconectado = !_isOnline;
    if (_isOnline != conectado) {
      setState(() => _isOnline = conectado);
      if (conectado && estabaDesconectado && _colaOffline.isNotEmpty) {
        _sincronizarColaPendiente();
      }
    } else if (conectado && _colaOffline.isNotEmpty && !_sincronizando) {
      _sincronizarColaPendiente();
    }
  }

  // Envía a PostgreSQL todas las maniobras acumuladas durante el corte de internet
  Future<void> _sincronizarColaPendiente() async {
    if (_sincronizando || _colaOffline.isEmpty || _licenciaBloqueada) return;
    setState(() => _sincronizando = true);

    final int cantidad = _colaOffline.length;
    final List restantes = [];

    for (final item in _colaOffline) {
      try {
        final res = await http
            .post(
              Uri.parse('${ApiConfig.baseUrl}/api/maniobras'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(item),
            )
            .timeout(const Duration(seconds: 3));
        if (res.statusCode != 200) {
          restantes.add(item);
        }
      } catch (_) {
        restantes.add(item);
      }
    }

    if (!mounted) return;
    setState(() {
      _colaOffline = restantes;
      _sincronizando = false;
    });
    _guardarColaLocal();

    if (restantes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Conexión restablecida: $cantidad maniobra(s) sincronizadas con PostgreSQL.',
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  // Gestiona los 3 pasos de la maniobra y guarda local u online según conectividad
  Future<void> _avanzarEtapaManiobra() async {
    if (_licenciaBloqueada) return;

    if (_etapaManiobra == 0) {
      setState(() => _etapaManiobra = 1);
      return;
    }

    if (_etapaManiobra == 1) {
      final tarea = _tareasAsignadas[_indiceTarea % _tareasAsignadas.length];
      final int duracion =
          DateTime.now().difference(_inicioManiobra).inSeconds.clamp(8, 999);

      final Map registroManiobra = {
        'grua_id': 'RTG-04',
        'operador': widget.nombreOperador,
        'contenedor': tarea['contenedor'],
        'origen': tarea['origen'],
        'destino': tarea['destino'],
        'duracion_seg': duracion,
        'origen_sync': _isOnline ? 'Online' : 'Offline Sync',
      };

      setState(() {
        _ultimaDuracionSeg = duracion;
        _etapaManiobra = 2;
      });

      if (_isOnline) {
        try {
          final res = await http
              .post(
                Uri.parse('${ApiConfig.baseUrl}/api/maniobras'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(registroManiobra),
              )
              .timeout(const Duration(seconds: 2));
          if (res.statusCode == 200 && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Maniobra registrada en tiempo real en el servidor.'),
                backgroundColor: Color(0xFF16A34A),
              ),
            );
            return;
          }
        } catch (_) {}
      }

      setState(() {
        _isOnline = false;
        _colaOffline.add(registroManiobra);
      });
      _guardarColaLocal();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sin conexión: Maniobra guardada localmente (${_colaOffline.length} en cola).',
            ),
            backgroundColor: const Color(0xFFD97706),
          ),
        );
      }
    }
  }

  void _siguienteAsignacion() {
    if (_licenciaBloqueada) return;
    setState(() {
      _indiceTarea++;
      _etapaManiobra = 0;
      _inicioManiobra = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tarea = _tareasAsignadas[_indiceTarea % _tareasAsignadas.length];
    final Color statusColor =
        _isOnline ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151F32),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.precision_manufacturing, color: Color(0xFFF59E0B)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TERMINAL EMBARCADO • GRÚA RTG-04',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                Text(
                  'Operador: ${widget.nombreOperador} (${widget.username}) • Modo Cabina Nocturna',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white60),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Indicador automático de estado de red (En línea / Modo Offline)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor),
            ),
            child: Row(
              children: [
                Icon(
                  _isOnline ? Icons.wifi : Icons.wifi_off,
                  color: statusColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _isOnline
                      ? 'EN LÍNEA • TELEMETRÍA ACTIVA'
                      : 'MODO OFFLINE (DETECCIÓN AUTO)',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const SelectorView()),
              (route) => false,
            ),
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            label: const Text('Salir',
                style: TextStyle(color: Colors.redAccent)),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Banner de aviso cuando hay maniobras guardadas localmente sin enviar
            if (!_isOnline || _colaOffline.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storage, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        !_isOnline
                            ? 'Conexión perdida: operando con respaldo local. Maniobras pendientes de envío: ${_colaOffline.length}'
                            : 'Sincronizando ${_colaOffline.length} maniobra(s) guardadas localmente...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ficha izquierda con datos técnicos del contenedor asignado
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151F32),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ORDEN DE MANIOBRA ASIGNADA',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  fontSize: 13,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'CICLO #${_indiceTarea + 1}',
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            tarea['contenedor'],
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tarea['tipo'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Divider(height: 30, color: Colors.white12),
                          _buildDatoCabina(
                              Icons.upload, 'ORIGEN EN PATIO', tarea['origen']),
                          const SizedBox(height: 14),
                          _buildDatoCabina(Icons.download,
                              'DESTINO DE TRANSFERENCIA', tarea['destino']),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDatoCabina(
                                    Icons.scale, 'PESO BRUTO', tarea['peso']),
                              ),
                              Expanded(
                                child: _buildDatoCabina(
                                    Icons.verified_user,
                                    'N° SELLO ADUANA',
                                    tarea['sello']),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B1120),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.shield,
                                    color: Color(0xFFF59E0B)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    tarea['alerta'],
                                    style: const TextStyle(
                                      color: Color(0xFFFCD34D),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  // Panel derecho con las 3 etapas y el botón táctil de confirmación
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151F32),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'PROGRESO DE MANIOBRA',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildPasoIndicador(
                            numero: '1',
                            titulo: 'Enganche y Twistlock en Patio',
                            activo: _etapaManiobra == 0,
                            completado: _etapaManiobra > 0,
                          ),
                          const SizedBox(height: 12),
                          _buildPasoIndicador(
                            numero: '2',
                            titulo: 'Traslado y Posicionamiento en Andén',
                            activo: _etapaManiobra == 1,
                            completado: _etapaManiobra > 1,
                          ),
                          const SizedBox(height: 12),
                          _buildPasoIndicador(
                            numero: '3',
                            titulo: 'Maniobra Finalizada y Liberada',
                            activo: _etapaManiobra == 2,
                            completado: _etapaManiobra == 2,
                          ),
                          const Spacer(),
                          if (_etapaManiobra == 2) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFF22C55E)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Color(0xFF22C55E), size: 38),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'MANIOBRA COMPLETADA',
                                    style: TextStyle(
                                      color: Color(0xFF22C55E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  Text(
                                    'Tiempo total de ciclo: $_ultimaDuracionSeg segundos',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 68,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _siguienteAsignacion,
                                icon: const Icon(Icons.refresh, size: 28),
                                label: const Text(
                                  'SOLICITAR SIGUIENTE ASIGNACIÓN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ] else
                            SizedBox(
                              height: 84,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _etapaManiobra == 0
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF22C55E),
                                  foregroundColor: const Color(0xFF0B1120),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _avanzarEtapaManiobra,
                                icon: Icon(
                                  _etapaManiobra == 0
                                      ? Icons.lock
                                      : Icons.check_circle_outline,
                                  size: 32,
                                ),
                                label: Text(
                                  _etapaManiobra == 0
                                      ? 'CONFIRMAR AGARRE\n(TWISTLOCK CERRADO)'
                                      : 'CONFIRMAR DESCARGA\nEN ${tarea['destino']}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatoCabina(IconData icono, String titulo, String valor) {
    return Row(
      children: [
        Icon(icono, color: const Color(0xFF38BDF8), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                valor,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasoIndicador({
    required String numero,
    required String titulo,
    required bool activo,
    required bool completado,
  }) {
    final Color color = completado
        ? const Color(0xFF22C55E)
        : activo
            ? const Color(0xFFF59E0B)
            : Colors.white24;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activo
            ? const Color(0xFFF59E0B).withValues(alpha: 0.14)
            : const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: activo ? 1.8 : 1.0),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color,
            child: completado
                ? const Icon(Icons.check, color: Color(0xFF0B1120), size: 18)
                : Text(
                    numero,
                    style: TextStyle(
                      color: activo ? const Color(0xFF0B1120) : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                color: activo || completado ? Colors.white : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}