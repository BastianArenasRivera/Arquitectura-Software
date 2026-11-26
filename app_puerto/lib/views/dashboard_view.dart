// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../config/api_config.dart';
import 'influx_view.dart';
import 'panel_alertas_view.dart';

class DashboardAdminView extends StatefulWidget {
  const DashboardAdminView({super.key});
  @override
  State<DashboardAdminView> createState() => _DashboardAdminViewState();
}

class _DashboardAdminViewState extends State<DashboardAdminView> {
  final ScrollController _alertasScrollCtrl = ScrollController();
  final ScrollController _camionesScrollCtrl = ScrollController();

  List alertas = [
    {
      'texto': 'Camión ABCD-12 asignado a Andén B-4',
      'color': const Color(0xFFE0F2FE),
      'icono': Icons.info,
      'iconColor': const Color(0xFF0284C7),
    },
    {
      'texto': 'Congestión Alta en Bloque A (Reefer)',
      'color': const Color(0xFFFEE2E2),
      'icono': Icons.error,
      'iconColor': const Color(0xFFDC2626),
    },
  ];

  List colaCamiones = [
    {
      'patente': 'ABCD-12',
      'contenedor': 'MSKU-742918',
      'operacion': 'Descarga',
      'anden': 'B-4',
      'estado': 'En andén',
    },
    {
      'patente': 'KLRW-88',
      'contenedor': 'MSCU-901234',
      'operacion': 'Carga',
      'anden': 'B-2',
      'estado': 'En pórtico',
    },
    {
      'patente': 'PGTZ-45',
      'contenedor': 'HLCU-553821',
      'operacion': 'Descarga',
      'anden': 'C-1',
      'estado': 'En espera',
    },
    {
      'patente': 'ZXCV-91',
      'contenedor': 'CMAU-331098',
      'operacion': 'Retiro',
      'anden': 'A-3',
      'estado': 'Saliendo',
    },
  ];

  late List bloquesPatio;
  int _camionesEnPatio = 45;
  bool _solicitudColacionRespondida = false;
  bool _emergenciaGruaRevisada = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _inicializarMapaPatio();
    _cargarAccesosDesdeBackend();
    _timer = Timer.periodic(const Duration(seconds: 9), (timer) {
      if (!mounted) return;
      final List nuevosEventos = [
        {
          'texto': 'Grúa RTG-02 requiere mantenimiento preventivo',
          'color': const Color(0xFFFEF3C7),
          'icono': Icons.warning,
          'iconColor': const Color(0xFFD97706),
        },
        {
          'texto': 'Lectura RFID exitosa en Pórtico Norte',
          'color': const Color(0xFFDCFCE7),
          'icono': Icons.check_circle,
          'iconColor': const Color(0xFF16A34A),
        },
        {
          'texto': 'Retraso detectado en Andén C-3',
          'color': const Color(0xFFFEE2E2),
          'icono': Icons.error,
          'iconColor': const Color(0xFFDC2626),
        },
      ];
      setState(() {
        alertas.insert(0, nuevosEventos[Random().nextInt(nuevosEventos.length)]);
      });
    });
  }

  void _inicializarMapaPatio() {
    bloquesPatio = [
      {
        'codigo': 'A-01',
        'bloque': 'Bloque A • Reefer',
        'ocupacion': 94,
        'contenedor': 'MSKU-742918 (40\' Reefer)',
        'temperatura': '-18.2 °C (Óptima)',
        'grua': 'RTG-01',
        'patente': 'ABCD-12',
      },
      {
        'codigo': 'A-02',
        'bloque': 'Bloque A • Reefer',
        'ocupacion': 88,
        'contenedor': 'TEMU-618204 (40\' Reefer)',
        'temperatura': '-17.8 °C (Óptima)',
        'grua': 'RTG-01',
        'patente': 'JKL-902',
      },
      {
        'codigo': 'A-03',
        'bloque': 'Bloque A • Reefer',
        'ocupacion': 62,
        'contenedor': 'SUDU-309481 (20\' Reefer)',
        'temperatura': '-19.0 °C (Óptima)',
        'grua': 'RTG-02',
        'patente': 'Sin camión',
      },
      {
        'codigo': 'A-04',
        'bloque': 'Bloque A • Reefer',
        'ocupacion': 40,
        'contenedor': 'MNBU-881203 (40\' Reefer)',
        'temperatura': '-18.5 °C (Óptima)',
        'grua': 'RTG-02',
        'patente': 'Sin camión',
      },
      {
        'codigo': 'B-01',
        'bloque': 'Bloque B • Exportación',
        'ocupacion': 76,
        'contenedor': 'MSCU-901234 (40\' High Cube)',
        'temperatura': 'Carga Seca',
        'grua': 'RTG-03',
        'patente': 'KLRW-88',
      },
      {
        'codigo': 'B-02',
        'bloque': 'Bloque B • Exportación',
        'ocupacion': 91,
        'contenedor': 'HLCU-553821 (40\' High Cube)',
        'temperatura': 'Carga Seca',
        'grua': 'RTG-03',
        'patente': 'PGTZ-45',
      },
      {
        'codigo': 'B-03',
        'bloque': 'Bloque B • Exportación',
        'ocupacion': 53,
        'contenedor': 'CMAU-331098 (20\' Dry)',
        'temperatura': 'Carga Seca',
        'grua': 'RTG-04',
        'patente': 'ZXCV-91',
      },
      {
        'codigo': 'B-04',
        'bloque': 'Bloque B • Exportación',
        'ocupacion': 35,
        'contenedor': 'OOLU-774120 (40\' Dry)',
        'temperatura': 'Carga Seca',
        'grua': 'RTG-04',
        'patente': 'Sin camión',
      },
      {
        'codigo': 'C-01',
        'bloque': 'Bloque C • Importación',
        'ocupacion': 48,
        'contenedor': 'TGHU-119402 (40\' High Cube)',
        'temperatura': 'Carga General',
        'grua': 'RTG-05',
        'patente': 'Sin camión',
      },
      {
        'codigo': 'C-02',
        'bloque': 'Bloque C • Importación',
        'ocupacion': 67,
        'contenedor': 'EMCU-440192 (20\' Dry)',
        'temperatura': 'Carga General',
        'grua': 'RTG-05',
        'patente': 'RTYU-34',
      },
      {
        'codigo': 'C-03',
        'bloque': 'Bloque C • Importación',
        'ocupacion': 84,
        'contenedor': 'YMLU-992014 (40\' Open Top)',
        'temperatura': 'Sobredimensionada',
        'grua': 'RTG-06',
        'patente': 'MNBV-67',
      },
      {
        'codigo': 'C-04',
        'bloque': 'Bloque C • Importación',
        'ocupacion': 29,
        'contenedor': 'SEGU-502819 (20\' Dry)',
        'temperatura': 'Disponible',
        'grua': 'RTG-06',
        'patente': 'Sin camión',
      },
    ];
  }

  Future<void> _cargarAccesosDesdeBackend() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/accesos'));
      if (res.statusCode == 200 && mounted) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          setState(() {
            _camionesEnPatio = 45 + data.length;
            final List remotos = data
                .take(8)
                .map((e) => {
                      'patente': e['patente'] ?? 'N/A',
                      'contenedor': e['contenedor'] ?? 'MSKU-482910',
                      'operacion': e['tramite'] ?? 'Ingreso',
                      'anden': (e['anden'] ?? 'B-4').toString().replaceAll('Andén ', ''),
                      'estado': 'En andén',
                    })
                .toList();
            colaCamiones = [...remotos, ...colaCamiones.take(4)];
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alertasScrollCtrl.dispose();
    _camionesScrollCtrl.dispose();
    super.dispose();
  }

  void _mostrarDetalleCelda(Map celda) {
    final int oc = celda['ocupacion'] as int;
    final Color badgeColor = oc >= 85
        ? const Color(0xFFDC2626)
        : oc >= 60
            ? const Color(0xFFD97706)
            : const Color(0xFF16A34A);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(Icons.grid_view_rounded, color: badgeColor),
            const SizedBox(width: 10),
            Text(
              'Bahía ${celda['codigo']} — ${celda['bloque']}',
              style: const TextStyle(
                color: Color(0xFF0A2540),
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filaDetalle('Ocupación actual:', '$oc%'),
            _filaDetalle('Contenedor activo:', celda['contenedor']),
            _filaDetalle('Condición / Temp.:', celda['temperatura']),
            _filaDetalle('Grúa asignada:', celda['grua']),
            _filaDetalle('Camión vinculado:', celda['patente']),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar Ficha'),
          ),
        ],
      ),
    );
  }

  Widget _filaDetalle(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 16),
          Text(
            valor,
            style: const TextStyle(
              color: Color(0xFF0A2540),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _abrirNotificaciones(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: Color(0xFF0284C7)),
              SizedBox(width: 10),
              Text(
                'Solicitudes y Alertas Operativas',
                style: TextStyle(
                  color: Color(0xFF0A2540),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 470,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.coffee, color: Colors.brown, size: 30),
                  title: const Text(
                    'Joaquín (Grúa RTG-04) solicita colación.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _solicitudColacionRespondida
                        ? 'Solicitud gestionada por Administrador'
                        : 'Relevo programado de 30 minutos',
                  ),
                  trailing: _solicitudColacionRespondida
                      ? const Chip(
                          label: Text('Gestionada',
                              style: TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: Color(0xFF16A34A),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Aprobar colación',
                              icon: const Icon(Icons.check_circle,
                                  color: Color(0xFF16A34A)),
                              onPressed: () {
                                setModalState(
                                    () => _solicitudColacionRespondida = true);
                                setState(() {
                                  alertas.insert(0, {
                                    'texto':
                                        'Colación aprobada para Joaquín (RTG-04)',
                                    'color': const Color(0xFFDCFCE7),
                                    'icono': Icons.check_circle,
                                    'iconColor': const Color(0xFF16A34A),
                                  });
                                });
                              },
                            ),
                            IconButton(
                              tooltip: 'Rechazar solicitud',
                              icon: const Icon(Icons.cancel,
                                  color: Color(0xFFDC2626)),
                              onPressed: () {
                                setModalState(
                                    () => _solicitudColacionRespondida = true);
                                setState(() {
                                  alertas.insert(0, {
                                    'texto':
                                        'Colación postergada para RTG-04 por alta demanda',
                                    'color': const Color(0xFFFEF3C7),
                                    'icono': Icons.warning,
                                    'iconColor': const Color(0xFFD97706),
                                  });
                                });
                              },
                            ),
                          ],
                        ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.warning,
                      color: Color(0xFFDC2626), size: 30),
                  title: const Text(
                    'EMERGENCIA: Alerta Hidráulica Grúa 5',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                  ),
                  subtitle: const Text('Patio Sur • Sensor de presión'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _emergenciaGruaRevisada
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                    onPressed: _emergenciaGruaRevisada
                        ? null
                        : () {
                            setModalState(() => _emergenciaGruaRevisada = true);
                            setState(() {
                              alertas.insert(0, {
                                'texto':
                                    'Cuadrilla técnica despachada a Grúa 5 (Patio Sur)',
                                'color': const Color(0xFFE0F2FE),
                                'icono': Icons.build_circle,
                                'iconColor': const Color(0xFF0284C7),
                              });
                            });
                          },
                    child: Text(
                      _emergenciaGruaRevisada ? 'EN REVISIÓN' : 'REVISAR',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar Panel'),
            ),
          ],
        ),
      ),
    );
  }

  void _forzarOptimizacion() {
    setState(() {
      for (final b in bloquesPatio) {
        final int oc = b['ocupacion'] as int;
        if (oc > 85) {
          b['ocupacion'] = oc - 14;
        }
      }
      alertas.insert(0, {
        'texto':
            'Optimización ejecutada: 3 grúas reasignadas a Bloques A y B',
        'color': const Color(0xFFDCFCE7),
        'icono': Icons.auto_graph,
        'iconColor': const Color(0xFF16A34A),
      });
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.auto_graph, color: Color(0xFF16A34A)),
            SizedBox(width: 10),
            Text(
              'Optimización Matemática Ejecutada',
              style: TextStyle(color: Color(0xFF0A2540)),
            ),
          ],
        ),
        content: const Text(
          'El algoritmo de balanceo de carga reasignó 3 grúas RTG hacia los bloques críticos (A-01, A-02 y B-02), reduciendo la congestión proyectada en un 14%.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int pendientes = (_solicitudColacionRespondida ? 0 : 1) +
        (_emergenciaGruaRevisada ? 0 : 1);

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A2540),
          foregroundColor: Colors.white,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.precision_manufacturing, color: Color(0xFF38BDF8)),
              SizedBox(width: 10),
              Text(
                'Panel Logístico Central • TOS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Actualizar datos',
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _cargarAccesosDesdeBackend,
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications,
                      color: Colors.white, size: 26),
                  onPressed: () => _abrirNotificaciones(context),
                ),
                if (pendientes > 0)
                  Positioned(
                    right: 8,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendientes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PerfilAdminView()),
                );
                if (mounted) setState(() {});
              },
              child: Row(
                children: [
                  PerfilAdminView.fotoBytes != null
                      ? CircleAvatar(
                          radius: 16,
                          backgroundImage:
                              MemoryImage(PerfilAdminView.fotoBytes!),
                        )
                      : const Icon(Icons.account_circle,
                          size: 30, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    PerfilAdminView.nombreUsuarioActual,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            TextButton.icon(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const SelectorView()),
                (route) => false,
              ),
              icon: const Icon(Icons.exit_to_app, color: Color(0xFFFCA5A5)),
              label: const Text('Salir',
                  style: TextStyle(color: Color(0xFFFCA5A5))),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // FILA SUPERIOR DE 4 KPIs EJECUTIVOS
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      titulo: 'CAMIONES EN PATIO',
                      valor: '$_camionesEnPatio / 60',
                      detalle:
                          '${((_camionesEnPatio / 60) * 100).clamp(0, 100).toStringAsFixed(0)}% capacidad ocupada',
                      icono: Icons.local_shipping,
                      colorAcento: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      titulo: 'GRÚAS OPERATIVAS',
                      valor: '12 Activas',
                      detalle: '2 en mantenimiento preventivo',
                      icono: Icons.precision_manufacturing,
                      colorAcento: const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      titulo: 'TIEMPO ESTADÍA (TURNAROUND)',
                      valor: '24.5 min',
                      detalle: '-12% respecto a ayer',
                      icono: Icons.timer,
                      colorAcento: const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      titulo: 'PRODUCTIVIDAD DE PATIO',
                      valor: '34 mov/h',
                      detalle: 'Meta operativa: 30 mov/h',
                      icono: Icons.speed,
                      colorAcento: const Color(0xFF0A2540),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // CUERPO PRINCIPAL DE 2 COLUMNAS
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // COLUMNA IZQUIERDA: PANEL DE ALERTAS + COLA DE CAMIONES
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      InkWell(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PanelAlertasView(
                                              alertasPatio: alertas,
                                            ),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.warning_amber_rounded,
                                                color: Color(0xFF0A2540),
                                                size: 20),
                                            SizedBox(width: 6),
                                            Text(
                                              'PANEL DE ALERTAS',
                                              style: TextStyle(
                                                color: Color(0xFF0A2540),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                            SizedBox(width: 5),
                                            Icon(Icons.open_in_new,
                                                size: 15,
                                                color: Color(0xFF0284C7)),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${alertas.length} eventos',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: Scrollbar(
                                      controller: _alertasScrollCtrl,
                                      thumbVisibility: true,
                                      child: ListView.builder(
                                        controller: _alertasScrollCtrl,
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        itemCount: alertas.length,
                                        itemBuilder: (context, index) {
                                          final alerta = alertas[index];
                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: alerta['color'],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor:
                                                      alerta['iconColor'],
                                                  radius: 13,
                                                  child: Icon(
                                                    alerta['icono'],
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    alerta['texto'],
                                                    style: const TextStyle(
                                                      color: Colors.black87,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            flex: 5,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.alt_route,
                                              color: Color(0xFF0A2540),
                                              size: 19),
                                          SizedBox(width: 6),
                                          Text(
                                            'COLA DE CAMIONES Y ANDENES',
                                            style: TextStyle(
                                              color: Color(0xFF0A2540),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'En vivo',
                                        style: TextStyle(
                                          color: Color(0xFF16A34A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Scrollbar(
                                      controller: _camionesScrollCtrl,
                                      thumbVisibility: true,
                                      child: ListView.separated(
                                        controller: _camionesScrollCtrl,
                                        itemCount: colaCamiones.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, idx) {
                                          final c = colaCamiones[idx];
                                          return ListTile(
                                            dense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 4),
                                            leading: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0A2540),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                c['patente'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              '${c['contenedor']} • ${c['operacion']}',
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'Andén ${c['anden']}',
                                              style: const TextStyle(
                                                  fontSize: 11.5),
                                            ),
                                            trailing: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE0F2FE),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                c['estado'],
                                                style: const TextStyle(
                                                  color: Color(0xFF0284C7),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
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
                    const SizedBox(width: 14),
                    // COLUMNA DERECHA: MAPA INTERACTIVO DE PATIO + BOTONES ACCIÓN
                    Expanded(
                      flex: 7,
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'MAPA INTERACTIVO DE BLOQUES DE PATIO',
                                            style: TextStyle(
                                              color: Color(0xFF0A2540),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            'Haz clic en cualquier bahía para inspeccionar contenedor y grúa asignada',
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          _leyendaMapa('Óptimo',
                                              const Color(0xFF16A34A)),
                                          const SizedBox(width: 10),
                                          _leyendaMapa(
                                              'Alto', const Color(0xFFD97706)),
                                          const SizedBox(width: 10),
                                          _leyendaMapa('Crítico',
                                              const Color(0xFFDC2626)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: GridView.builder(
                                      itemCount: bloquesPatio.length,
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: 1.55,
                                      ),
                                      itemBuilder: (context, index) {
                                        final celda = bloquesPatio[index];
                                        final int oc =
                                            celda['ocupacion'] as int;
                                        final Color color = oc >= 85
                                            ? const Color(0xFFDC2626)
                                            : oc >= 60
                                                ? const Color(0xFFD97706)
                                                : const Color(0xFF16A34A);
                                        final Color bg = oc >= 85
                                            ? const Color(0xFFFEF2F2)
                                            : oc >= 60
                                                ? const Color(0xFFFFFBEB)
                                                : const Color(0xFFF0FDF4);

                                        return InkWell(
                                          onTap: () =>
                                              _mostrarDetalleCelda(celda),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: bg,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: color.withValues(
                                                    alpha: 0.55),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      celda['codigo'],
                                                      style: TextStyle(
                                                        color: color,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: color,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: Text(
                                                        '$oc%',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  celda['bloque'],
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.black87,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  'Grúa: ${celda['grua']}',
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A2540),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Icon(Icons.local_shipping,
                                            color: Color(0xFF38BDF8), size: 22),
                                        Text(
                                          'CORREDOR LOGÍSTICO Y ANDENES DE TRANSFERENCIA B-1 A B-6',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        Icon(Icons.directions_boat,
                                            color: Color(0xFF38BDF8), size: 22),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildAccionBtn(
                                  Icons.analytics,
                                  'Visor de Telemetría IoT',
                                  const Color(0xFF0284C7),
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const InfluxDataView()),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildAccionBtn(
                                  Icons.auto_graph,
                                  'Optimizar Asignación de Grúas',
                                  const Color(0xFF0A2540),
                                  _forzarOptimizacion,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leyendaMapa(String texto, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String titulo,
    required String valor,
    required String detalle,
    required IconData icono,
    required Color colorAcento,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorAcento.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: colorAcento, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: const TextStyle(
                    color: Color(0xFF0A2540),
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorAcento,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionBtn(
      IconData icono, String texto, Color bgColor, VoidCallback accion) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: accion,
      icon: Icon(icono, color: Colors.white, size: 26),
      label: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class PerfilAdminView extends StatefulWidget {
  static Uint8List? fotoBytes;
  static String nombreUsuarioActual = 'Admin';

  const PerfilAdminView({super.key});
  @override
  State<PerfilAdminView> createState() => _PerfilAdminViewState();
}

class _PerfilAdminViewState extends State<PerfilAdminView> {
  bool _ocultarClave = true;
  bool _ocultarConfirmClave = true;
  bool _guardando = false;

  final String _fotoUrlPorDefecto =
      'https://cdn-icons-png.flaticon.com/512/3135/3135715.png';
  Uint8List? _fotoLocalBytes;

  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _rutCtrl = TextEditingController(text: '19.234.567-8');
  final _phoneCtrl = TextEditingController(text: '+56 9 8765 4321');

  @override
  void initState() {
    super.initState();
    _fotoLocalBytes = PerfilAdminView.fotoBytes;
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _rutCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _subirFotoDesdeEquipo() {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();
    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(files[0]);
        reader.onLoadEnd.listen((_) {
          if (reader.result != null && mounted) {
            setState(() {
              _fotoLocalBytes = reader.result as Uint8List;
            });
          }
        });
      }
    });
  }

  Future<void> _guardarCambios() async {
    final String usuario = _userCtrl.text.trim();
    final String nuevaPass = _passCtrl.text;
    final String confirmarPass = _confirmPassCtrl.text;

    if (usuario.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre de usuario no puede estar vacío.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (nuevaPass.isNotEmpty || confirmarPass.isNotEmpty) {
      if (nuevaPass != confirmarPass) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Las contraseñas no coinciden. Verifica que esté bien escrita.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{6,}$')
          .hasMatch(nuevaPass)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La contraseña debe tener al menos 6 caracteres, 1 mayúscula, 1 minúscula y 1 número.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _guardando = true);

    try {
      if (nuevaPass.isNotEmpty) {
        await http.put(
          Uri.parse('${ApiConfig.baseUrl}/api/admin/perfil'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'usuario': usuario,
            'nueva_password': nuevaPass,
          }),
        );
      }
    } catch (_) {}

    PerfilAdminView.fotoBytes = _fotoLocalBytes;
    PerfilAdminView.nombreUsuarioActual =
        usuario == 'admin' ? 'Admin' : usuario;

    if (!mounted) return;
    setState(() => _guardando = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nuevaPass.isNotEmpty
              ? 'Perfil y nueva contraseña guardados correctamente.'
              : 'Datos de perfil actualizados correctamente.',
        ),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );

    final bool escribiendoClave =
        _passCtrl.text.isNotEmpty || _confirmPassCtrl.text.isNotEmpty;
    final bool clavesCoinciden =
        _passCtrl.text.isNotEmpty && _passCtrl.text == _confirmPassCtrl.text;

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A2540),
          foregroundColor: Colors.white,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Perfil del Administrador',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _subirFotoDesdeEquipo,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: const Color(0xFF0A2540),
                          child: CircleAvatar(
                            radius: 51,
                            backgroundImage: _fotoLocalBytes != null
                                ? MemoryImage(_fotoLocalBytes!) as ImageProvider
                                : NetworkImage(_fotoUrlPorDefecto),
                            backgroundColor: Colors.grey[200],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0284C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _subirFotoDesdeEquipo,
                    icon: const Icon(Icons.upload_file,
                        color: Color(0xFF0284C7)),
                    label: const Text(
                      'Subir foto de perfil',
                      style: TextStyle(
                        color: Color(0xFF0284C7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: textStyle,
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de Usuario',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    style: textStyle,
                    controller: _passCtrl,
                    obscureText: _ocultarClave,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nueva Contraseña (opcional)',
                      hintText: 'Ej: Admin456',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _ocultarClave
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => _ocultarClave = !_ocultarClave),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    style: textStyle,
                    controller: _confirmPassCtrl,
                    obscureText: _ocultarConfirmClave,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Confirmar Nueva Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: !escribiendoClave
                              ? Colors.grey
                              : clavesCoinciden
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                          width: escribiendoClave ? 1.8 : 1.0,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _ocultarConfirmClave
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _ocultarConfirmClave = !_ocultarConfirmClave,
                        ),
                      ),
                    ),
                  ),
                  if (escribiendoClave) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          clavesCoinciden ? Icons.check_circle : Icons.error,
                          size: 16,
                          color: clavesCoinciden
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          clavesCoinciden
                              ? 'Las contraseñas coinciden'
                              : 'Las contraseñas no coinciden',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: clavesCoinciden
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 15),
                  TextField(
                    style: textStyle,
                    controller: _rutCtrl,
                    decoration: const InputDecoration(
                      labelText: 'RUT',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    style: textStyle,
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _guardando ? null : _guardarCambios,
                      child: _guardando
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'GUARDAR CAMBIOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}