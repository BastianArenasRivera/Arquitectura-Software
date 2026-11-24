import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InfluxDataView extends StatefulWidget {
  const InfluxDataView({super.key});

  @override
  State<InfluxDataView> createState() => _InfluxDataViewState();
}

class _InfluxDataViewState extends State<InfluxDataView> {
  static const String baseUrl = 'http://172.22.0.223:8000';

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  DateTimeRange? _rangoFechas;
  String _dispositivoFiltro = 'Todos';
  String _estadoFiltro = 'Todos';

  late List> _registrosHistoricos;
  Set<String> _reportadosIds = {};

  final List<String> _dispositivos = const [
    'Antena_RFID_Norte',
    'Sensor_Temp_Reefer',
    'Telemetria_Grua_04',
    'Camara_IP_Acceso',
  ];

  @override
  void initState() {
    super.initState();
    _generarHistorialBase();
    _cargarReportesExistentes();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  /// Genera historial distribuido en los últimos 90 días para probar el filtro de fechas
  void _generarHistorialBase() {
    final Random random = Random(42);
    final ahora = DateTime.now();

    _registrosHistoricos = List.generate(150, (index) {
      // Distribuye registros en horas y días anteriores
      final fecha = ahora.subtract(Duration(hours: index * 10, minutes: (index * 7) % 60));
      final int tipo = index % 4;
      final String dispositivo = _dispositivos[tipo];

      String metrica;
      String valorTexto;
      String severidad = 'normal'; // 'normal', 'leve', 'grave'

      if (tipo == 0) {
        metrica = 'tag_leido';
        if (index % 17 == 0) {
          valorTexto = 'ERROR_LECTURA_RFID';
          severidad = 'grave';
        } else if (index % 11 == 0) {
          valorTexto = 'SEÑAL_DEBIL_TAG';
          severidad = 'leve';
        } else {
          valorTexto = 'TAG-ABCD${10 + random.nextInt(89)}';
        }
      } else if (tipo == 1) {
        metrica = 'temperatura_c';
        // Contenedor refrigerado: normal entre -20 °C y -10 °C
        if (index % 13 == 0) {
          final temp = 2 + random.nextInt(8);
          valorTexto = '+$temp °C';
          severidad = 'grave';
        } else if (index % 7 == 0) {
          final temp = -4 - random.nextInt(4);
          valorTexto = '$temp °C';
          severidad = 'leve';
        } else {
          final temp = -10 - random.nextInt(10);
          valorTexto = '$temp °C';
        }
      } else if (tipo == 2) {
        metrica = 'rpm_motor';
        // Grúa: normal 600-1650 RPM
        if (index % 15 == 0) {
          final rpm = 1900 + random.nextInt(300);
          valorTexto = '$rpm RPM';
          severidad = 'grave';
        } else if (index % 9 == 0) {
          final rpm = 1700 + random.nextInt(150);
          valorTexto = '$rpm RPM';
          severidad = 'leve';
        } else {
          final rpm = 650 + random.nextInt(950);
          valorTexto = '$rpm RPM';
        }
      } else {
        metrica = 'ancho_banda_mbps';
        // Cámara IP: normal 35-95 Mbps
        if (index % 19 == 0) {
          final mbps = 2 + random.nextInt(6);
          valorTexto = '$mbps Mbps';
          severidad = 'grave';
        } else if (index % 10 == 0) {
          final mbps = 12 + random.nextInt(10);
          valorTexto = '$mbps Mbps';
          severidad = 'leve';
        } else {
          final mbps = 40 + random.nextInt(55);
          valorTexto = '$mbps Mbps';
        }
      }

      final String idUnico = 'REG-${fecha.millisecondsSinceEpoch}-$index';

      return {
        'id': idUnico,
        'fecha': fecha,
        'timestamp': fecha.toString().substring(0, 19),
        'dispositivo': dispositivo,
        'metrica': metrica,
        'valor': valorTexto,
        'severidad': severidad,
      };
    });
  }

  Future<void> _cargarReportesExistentes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/reportes-dispositivos'));
      if (res.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _reportadosIds = data.map((e) => e['registro_id'].toString()).toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _seleccionarRangoTiempo() async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: ahora,
      initialDateRange: _rangoFechas ??
          DateTimeRange(
            start: ahora.subtract(const Duration(days: 15)),
            end: ahora,
          ),
      helpText: 'Seleccionar Rango de Tiempo Histórico',
      cancelText: 'Cancelar',
      confirmText: 'Filtrar',
      saveText: 'Aplicar',
    );

    if (rango != null) {
      setState(() => _rangoFechas = rango);
    }
  }

  Future<void> _reportarAnomalia(Map<String, dynamic> reg) async {
    final String regId = reg['id'];

    if (_reportadosIds.contains(regId)) {
      _mostrarPopupYaReportado();
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/reportes-dispositivos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'registro_id': regId,
          'dispositivo': reg['dispositivo'],
          'metrica': reg['metrica'],
          'valor': reg['valor'],
          'severidad': reg['severidad'],
          'descripcion': 'Anomalía (${reg['valor']}) detectada en ${reg['dispositivo']}',
          'fecha_registro': (reg['fecha'] as DateTime).toIso8601String(),
        }),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _reportadosIds.add(regId);
        });

        if (body['ya_reportado'] == true) {
          _mostrarPopupYaReportado();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reporte enviado al Panel de Alertas'),
              backgroundColor: Color(0xFF0A2540),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo conectar con el servidor: $e')),
        );
      }
    }
  }

  void _mostrarPopupYaReportado() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 10),
            Text('Aviso'),
          ],
        ),
        content: const Text(
          'El problema ya ha sido reportado',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  List> get _registrosFiltrados {
    return _registrosHistoricos.where((reg) {
      // 1. Filtro de dispositivo
      if (_dispositivoFiltro != 'Todos' && reg['dispositivo'] != _dispositivoFiltro) {
        return false;
      }

      // 2. Filtro de severidad/estado
      if (_estadoFiltro == 'Anormales' && reg['severidad'] == 'normal') return false;
      if (_estadoFiltro == 'Graves' && reg['severidad'] != 'grave') return false;
      if (_estadoFiltro == 'Levemente graves' && reg['severidad'] != 'leve') return false;

      // 3. Filtro de rango de tiempo
      if (_rangoFechas != null) {
        final DateTime fecha = reg['fecha'];
        final inicio = DateTime(
          _rangoFechas!.start.year,
          _rangoFechas!.start.month,
          _rangoFechas!.start.day,
        );
        final fin = DateTime(
          _rangoFechas!.end.year,
          _rangoFechas!.end.month,
          _rangoFechas!.end.day,
          23,
          59,
          59,
        );
        if (fecha.isBefore(inicio) || fecha.isAfter(fin)) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textoRango = _rangoFechas == null
        ? 'Seleccionar Rango de Tiempo'
        : '${_rangoFechas!.start.day}/${_rangoFechas!.start.month}/${_rangoFechas!.start.year} - '
            '${_rangoFechas!.end.day}/${_rangoFechas!.end.month}/${_rangoFechas!.end.year}';

    final listaVisible = _registrosFiltrados;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2540),
        title: const Text(
          'Visor de Telemetría - San Antonio',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Registros Históricos de Telemetría',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                Text(
                  'Mostrando ${listaVisible.length} registros',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Barra de filtros: Rango de tiempo + Dispositivos + Estado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2540),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: _seleccionarRangoTiempo,
                    icon: const Icon(Icons.date_range),
                    label: Text(textoRango),
                  ),
                  if (_rangoFechas != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _rangoFechas = null),
                      icon: const Icon(Icons.clear, color: Colors.red),
                      label: const Text('Quitar rango', style: TextStyle(color: Colors.red)),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Dispositivo: ',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      DropdownButton<String>(
                        value: _dispositivoFiltro,
                        items: ['Todos', ..._dispositivos]
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d, style: const TextStyle(color: Colors.black)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _dispositivoFiltro = val);
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Estado: ',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      DropdownButton<String>(
                        value: _estadoFiltro,
                        items: const [
                          DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                          DropdownMenuItem(value: 'Anormales', child: Text('Solo anormales')),
                          DropdownMenuItem(value: 'Graves', child: Text('Graves (Rojo)')),
                          DropdownMenuItem(
                              value: 'Levemente graves', child: Text('Levemente graves (Amarillo)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _estadoFiltro = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tabla con barra de desplazamiento arrastrable (Scrollbar)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[400]!, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  thickness: 10,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    scrollDirection: Axis.vertical,
                    child: Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      interactive: true,
                      thickness: 10,
                      notificationPredicate: (n) => n.depth == 1,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                          columns: const [
                            DataColumn(
                              label: Text('Timestamp',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontSize: 15)),
                            ),
                            DataColumn(
                              label: Text('Dispositivo (IoT)',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontSize: 15)),
                            ),
                            DataColumn(
                              label: Text('Métrica',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontSize: 15)),
                            ),
                            DataColumn(
                              label: Text('Valor',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontSize: 15)),
                            ),
                          ],
                          rows: listaVisible.map((reg) {
                            final String severidad = reg['severidad'];
                            final bool yaReportado = _reportadosIds.contains(reg['id']);
                            final bool esGrave = severidad == 'grave';
                            final bool esLeve = severidad == 'leve';

                            return DataRow(
                              cells: [
                                DataCell(Text(reg['timestamp'],
                                    style: const TextStyle(
                                        color: Colors.black, fontWeight: FontWeight.w500))),
                                DataCell(Text(reg['dispositivo'],
                                    style: const TextStyle(
                                        color: Colors.black, fontWeight: FontWeight.w500))),
                                DataCell(Text(reg['metrica'],
                                    style: const TextStyle(
                                        color: Colors.black, fontWeight: FontWeight.w500))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        reg['valor'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: esGrave
                                              ? Colors.red[800]
                                              : esLeve
                                                  ? Colors.amber[900]
                                                  : Colors.black,
                                        ),
                                      ),
                                      if ((esGrave || esLeve) && !yaReportado) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          tooltip: esGrave
                                              ? 'Problema grave: presionar para reportar'
                                              : 'Problema levemente grave: presionar para reportar',
                                          icon: Icon(
                                            Icons.warning_rounded,
                                            color: esGrave ? Colors.red : Colors.amber[700],
                                            size: 24,
                                          ),
                                          onPressed: () => _reportarAnomalia(reg),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}