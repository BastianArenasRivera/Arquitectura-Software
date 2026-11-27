// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// Vista de monitoreo histórico IoT con filtros por fecha, dispositivo, estado y exportación CSV
class InfluxDataView extends StatefulWidget {
  const InfluxDataView({super.key});
  @override
  State<InfluxDataView> createState() => _InfluxDataViewState();
}

class _InfluxDataViewState extends State<InfluxDataView> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  String _dispositivoFiltro = 'Todos';
  String _estadoFiltro = 'Todos';

  late List _registrosHistoricos;
  Set<String> _reportadosIds = {};

  final List<String> _dispositivos = const [
    'Antena_RFID_Norte',
    'Sensor_Temp_Reefer',
    'Telemetria_Grua_04',
    'Camara_IP_Acceso',
  ];

  final List<String> _estadosOpciones = const [
    'Todos',
    'Anormales',
    'Graves',
    'Levemente graves',
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

  // Genera una serie histórica determinística (2024-2026) con lecturas normales, leves y graves
  void _generarHistorialBase() {
    final Random random = Random(42);
    final DateTime inicioBase = DateTime(2024, 1, 2, 8, 0);
    final DateTime limiteActual = DateTime.now();

    final List generados = [];

    for (int index = 0; index < 360; index++) {
      final DateTime fecha = inicioBase.add(
        Duration(hours: index * 70, minutes: (index * 13) % 60),
      );
      if (fecha.isAfter(limiteActual)) break;

      final int tipo = index % 4;
      final String dispositivo = _dispositivos[tipo];

      String metrica;
      String valorTexto;
      String severidad = 'normal';

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
        if (index % 13 == 0) {
          valorTexto = '+${2 + random.nextInt(8)} °C';
          severidad = 'grave';
        } else if (index % 7 == 0) {
          valorTexto = '-${4 + random.nextInt(4)} °C';
          severidad = 'leve';
        } else {
          valorTexto = '-${10 + random.nextInt(10)} °C';
        }
      } else if (tipo == 2) {
        metrica = 'rpm_motor';
        if (index % 15 == 0) {
          valorTexto = '${1900 + random.nextInt(300)} RPM';
          severidad = 'grave';
        } else if (index % 9 == 0) {
          valorTexto = '${1700 + random.nextInt(150)} RPM';
          severidad = 'leve';
        } else {
          valorTexto = '${650 + random.nextInt(950)} RPM';
        }
      } else {
        metrica = 'ancho_banda_mbps';
        if (index % 19 == 0) {
          valorTexto = '${2 + random.nextInt(6)} Mbps';
          severidad = 'grave';
        } else if (index % 10 == 0) {
          valorTexto = '${12 + random.nextInt(10)} Mbps';
          severidad = 'leve';
        } else {
          valorTexto = '${40 + random.nextInt(55)} Mbps';
        }
      }

      generados.add({
        'id': 'REG-${fecha.millisecondsSinceEpoch}-$index',
        'fecha': fecha,
        'timestamp': fecha.toString().substring(0, 19),
        'dispositivo': dispositivo,
        'metrica': metrica,
        'valor': valorTexto,
        'severidad': severidad,
      });
    }

    _registrosHistoricos = generados.reversed.toList();
  }

  // Consulta qué anomalías ya fueron reportadas para ocultar su ícono de advertencia
  Future<void> _cargarReportesExistentes() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/reportes-dispositivos'),
      );
      if (res.statusCode == 200 && mounted) {
        final List data = jsonDecode(res.body);
        setState(() {
          _reportadosIds = data.map((e) => e['registro_id'].toString()).toSet();
        });
      }
    } catch (_) {}
  }

  String _formatearFechaCorta(DateTime? f) {
    if (f == null) return 'Seleccionar';
    final d = f.day.toString().padLeft(2, '0');
    final m = f.month.toString().padLeft(2, '0');
    return '$d/$m/${f.year}';
  }

  // Abre el calendario para elegir la fecha inicial (Desde)
  Future<void> _seleccionarFechaDesde() async {
    final ahora = DateTime.now();
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaDesde ?? DateTime(2024, 1, 1),
      firstDate: DateTime(2024, 1, 1),
      lastDate: _fechaHasta ?? ahora,
      helpText: 'Seleccionar fecha inicial (Desde)',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0A2540),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF0A2540),
          ),
        ),
        child: child!,
      ),
    );
    if (seleccionada != null) {
      setState(() => _fechaDesde = seleccionada);
    }
  }

  // Abre el calendario para elegir la fecha final (Hasta)
  Future<void> _seleccionarFechaHasta() async {
    final ahora = DateTime.now();
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaHasta ?? ahora,
      firstDate: _fechaDesde ?? DateTime(2024, 1, 1),
      lastDate: ahora,
      helpText: 'Seleccionar fecha final (Hasta)',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0A2540),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF0A2540),
          ),
        ),
        child: child!,
      ),
    );
    if (seleccionada != null) {
      setState(() => _fechaHasta = seleccionada);
    }
  }

  // Descarga en el navegador un archivo CSV con los registros filtrados en pantalla
  void _exportarCsv(List registros) {
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Dispositivo,Metrica,Valor,Severidad');
    for (final reg in registros) {
      buffer.writeln(
        '"${reg['timestamp']}","${reg['dispositivo']}","${reg['metrica']}","${reg['valor']}","${reg['severidad']}"',
      );
    }
    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'telemetria_puerto.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // Envía una lectura anómala a PostgreSQL para mostrarla en el Panel de Alertas
  Future<void> _reportarAnomalia(Map reg) async {
    final String regId = reg['id'];
    if (_reportadosIds.contains(regId)) {
      _mostrarPopupYaReportado();
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/reportes-dispositivos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'registro_id': regId,
          'dispositivo': reg['dispositivo'],
          'metrica': reg['metrica'],
          'valor': reg['valor'],
          'severidad': reg['severidad'],
          'descripcion':
              'Anomalía (${reg['valor']}) detectada en ${reg['dispositivo']}',
          'fecha_registro': (reg['fecha'] as DateTime).toIso8601String(),
        }),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _reportadosIds.add(regId));
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
          SnackBar(content: Text('Error al conectar: $e')),
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

  String _etiquetaEstado(String valor) {
    switch (valor) {
      case 'Anormales':
        return 'Solo anormales';
      case 'Graves':
        return 'Graves (Rojo)';
      case 'Levemente graves':
        return 'Levemente graves (Amarillo)';
      default:
        return 'Todos';
    }
  }

  // Filtra la lista según fechas Desde/Hasta, dispositivo y severidad
  List get _registrosFiltrados {
    return _registrosHistoricos.where((reg) {
      if (_dispositivoFiltro != 'Todos' &&
          reg['dispositivo'] != _dispositivoFiltro) {
        return false;
      }
      if (_estadoFiltro == 'Anormales' && reg['severidad'] == 'normal') {
        return false;
      }
      if (_estadoFiltro == 'Graves' && reg['severidad'] != 'grave') {
        return false;
      }
      if (_estadoFiltro == 'Levemente graves' && reg['severidad'] != 'leve') {
        return false;
      }

      final DateTime fecha = reg['fecha'];
      if (_fechaDesde != null) {
        final inicio = DateTime(
          _fechaDesde!.year,
          _fechaDesde!.month,
          _fechaDesde!.day,
        );
        if (fecha.isBefore(inicio)) return false;
      }
      if (_fechaHasta != null) {
        final fin = DateTime(
          _fechaHasta!.year,
          _fechaHasta!.month,
          _fechaHasta!.day,
          23,
          59,
          59,
        );
        if (fecha.isAfter(fin)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final listaVisible = _registrosFiltrados;
    final int totalNormales =
        listaVisible.where((r) => r['severidad'] == 'normal').length;
    final int totalLeves =
        listaVisible.where((r) => r['severidad'] == 'leve').length;
    final int totalGraves =
        listaVisible.where((r) => r['severidad'] == 'grave').length;
    final opcionesDispositivos = ['Todos', ..._dispositivos];

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
            'Visor de Telemetría - San Antonio',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _exportarCsv(listaVisible),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Exportar CSV',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera con título y contadores dinámicos por severidad
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Registros Históricos de Telemetría',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2540),
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      _buildResumenChip('Total: ${listaVisible.length}',
                          const Color(0xFF0A2540)),
                      _buildResumenChip(
                          'Normales: $totalNormales', const Color(0xFF16A34A)),
                      _buildResumenChip(
                          'Leves: $totalLeves', const Color(0xFFD97706)),
                      _buildResumenChip(
                          'Graves: $totalGraves', const Color(0xFFDC2626)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Barra de filtros: Desde, Hasta, Dispositivo y Estado
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Recuadro de selección fecha inicial (Desde)
                    InkWell(
                      onTap: _seleccionarFechaDesde,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF0A2540), width: 1.3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 17, color: Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            Text(
                              'Desde: ${_formatearFechaCorta(_fechaDesde)}',
                              style: const TextStyle(
                                color: Color(0xFF0A2540),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Recuadro de selección fecha final (Hasta)
                    InkWell(
                      onTap: _seleccionarFechaHasta,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF0A2540), width: 1.3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event,
                                size: 17, color: Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            Text(
                              'Hasta: ${_formatearFechaCorta(_fechaHasta)}',
                              style: const TextStyle(
                                color: Color(0xFF0A2540),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_fechaDesde != null || _fechaHasta != null)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _fechaDesde = null;
                          _fechaHasta = null;
                        }),
                        icon: const Icon(Icons.clear,
                            color: Color(0xFFDC2626), size: 18),
                        label: const Text('Limpiar fechas',
                            style: TextStyle(color: Color(0xFFDC2626))),
                      ),
                    // Desplegable de filtro por sensor/dispositivo
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Dispositivo: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2540),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4F8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF0A2540), width: 1.3),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _dispositivoFiltro,
                              dropdownColor: const Color(0xFF0A2540),
                              borderRadius: BorderRadius.circular(10),
                              iconEnabledColor: const Color(0xFF0A2540),
                              selectedItemBuilder: (context) =>
                                  opcionesDispositivos
                                      .map(
                                        (d) => Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            d,
                                            style: const TextStyle(
                                              color: Color(0xFF0A2540),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              items: opcionesDispositivos
                                  .map(
                                    (d) => DropdownMenuItem<String>(
                                      value: d,
                                      child: Text(
                                        d,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _dispositivoFiltro = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Desplegable de filtro por severidad
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Estado: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2540),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4F8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF0A2540), width: 1.3),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _estadoFiltro,
                              dropdownColor: const Color(0xFF0A2540),
                              borderRadius: BorderRadius.circular(10),
                              iconEnabledColor: const Color(0xFF0A2540),
                              selectedItemBuilder: (context) => _estadosOpciones
                                  .map(
                                    (e) => Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _etiquetaEstado(e),
                                        style: const TextStyle(
                                          color: Color(0xFF0A2540),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              items: _estadosOpciones
                                  .map(
                                    (e) => DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(
                                        _etiquetaEstado(e),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _estadoFiltro = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Tabla scrollable a ancho completo con botón de reporte en valores anómalos
              Expanded(
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Scrollbar(
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
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    const Color(0xFFE2E8F0),
                                  ),
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'Timestamp',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0A2540),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Dispositivo (IoT)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0A2540),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Métrica',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0A2540),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Valor',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0A2540),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: listaVisible.map((reg) {
                                    final String severidad = reg['severidad'];
                                    final bool yaReportado =
                                        _reportadosIds.contains(reg['id']);
                                    final bool esGrave = severidad == 'grave';
                                    final bool esLeve = severidad == 'leve';

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            reg['timestamp'],
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            reg['dispositivo'],
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            reg['metrica'],
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
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
                                                      ? const Color(0xFFDC2626)
                                                      : esLeve
                                                          ? const Color(
                                                              0xFFD97706)
                                                          : Colors.black,
                                                ),
                                              ),
                                              if ((esGrave || esLeve) &&
                                                  !yaReportado) ...[
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  tooltip: esGrave
                                                      ? 'Problema grave: reportar'
                                                      : 'Problema levemente grave: reportar',
                                                  icon: Icon(
                                                    Icons.warning_rounded,
                                                    color: esGrave
                                                        ? const Color(
                                                            0xFFDC2626)
                                                        : const Color(
                                                            0xFFD97706),
                                                    size: 24,
                                                  ),
                                                  onPressed: () =>
                                                      _reportarAnomalia(reg),
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
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumenChip(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}