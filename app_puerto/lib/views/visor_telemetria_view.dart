import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VisorTelemetriaView extends StatefulWidget {
  const VisorTelemetriaView({super.key});

  @override
  State<VisorTelemetriaView> createState() => _VisorTelemetriaViewState();
}

class _VisorTelemetriaViewState extends State<VisorTelemetriaView> {
  static const String baseUrl = 'http://172.22.0.223:8000';

  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();

  DateTimeRange? _rangoFechas;
  String _dispositivoSeleccionado = 'Todos';
  String _filtroSeveridad = 'Todos';

  List> _registros = [];
  Set<String> _idsYaReportados = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      // 1. Cargar IDs de registros ya reportados para no volver a mostrar el ícono
      final resReportes = await http.get(Uri.parse('$baseUrl/api/reportes-dispositivos'));
      if (resReportes.statusCode == 200) {
        final List<dynamic> listaRep = jsonDecode(resReportes.body);
        _idsYaReportados = listaRep.map((e) => e['registro_id'].toString()).toSet();
      }

      // 2. Cargar registros históricos (ajusta la ruta si tu endpoint se llama distinto)
      final resTel = await http.get(Uri.parse('$baseUrl/api/telemetria'));
      if (resTel.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resTel.body);
        _registros = data.cast>();
      }
    } catch (_) {
      // Fallback de estructura en caso de prueba sin datos previos
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Clasifica el valor: 'grave' (rojo), 'leve' (amarillo) o 'normal'
  String _evaluarSeveridad(String metrica, dynamic valorRaw) {
    final double? val = double.tryParse(valorRaw.toString());
    if (val == null) return 'normal';

    final m = metrica.toLowerCase();
    if (m.contains('temp')) {
      if (val >= 85.0) return 'grave';
      if (val >= 70.0) return 'leve';
    } else if (m.contains('vibracion')) {
      if (val >= 8.0) return 'grave';
      if (val >= 5.0) return 'leve';
    } else if (m.contains('carga') || m.contains('peso')) {
      if (val >= 95.0) return 'grave';
      if (val >= 80.0) return 'leve';
    } else {
      // Umbral genérico porcentual o numérico alto
      if (val >= 90.0) return 'grave';
      if (val >= 75.0) return 'leve';
    }
    return 'normal';
  }

  String _generarRegistroId(Map<String, dynamic> reg) {
    return reg['id']?.toString() ??
        '${reg['dispositivo']}_${reg['metrica']}_${reg['timestamp']}';
  }

  Future<void> _seleccionarRangoTiempo() async {
    final ahora = DateTime.now();
    final seleccionado = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: ahora,
      initialDateRange: _rangoFechas ??
          DateTimeRange(
            start: ahora.subtract(const Duration(days: 30)),
            end: ahora,
          ),
      helpText: 'Seleccionar rango histórico',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );

    if (seleccionado != null) {
      setState(() => _rangoFechas = seleccionado);
    }
  }

  Future<void> _reportarProblema(
    Map<String, dynamic> reg,
    String registroId,
    String severidad,
  ) async {
    // Si ya fue reportado localmente, mostrar popup inmediato
    if (_idsYaReportados.contains(registroId)) {
      _mostrarPopupYaReportado();
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reportes-dispositivos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'registro_id': registroId,
          'dispositivo': reg['dispositivo']?.toString() ?? 'Dispositivo',
          'metrica': reg['metrica']?.toString() ?? 'Métrica',
          'valor': reg['valor']?.toString() ?? '',
          'severidad': severidad,
          'descripcion':
              'Valor anormal detectado (${reg['valor']}) en ${reg['metrica']}',
          'fecha_registro':
              reg['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _idsYaReportados.add(registroId);
        });

        if (body['ya_reportado'] == true) {
          _mostrarPopupYaReportado();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Problema agregado al Panel de Alertas'),
              backgroundColor: Color(0xFF0EA5E9),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reportar: $e')),
        );
      }
    }
  }

  void _mostrarPopupYaReportado() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Text('Aviso de Reporte', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'El problema ya ha sido reportado',
          style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido', style: TextStyle(color: Color(0xFF0EA5E9))),
          ),
        ],
      ),
    );
  }

  List> get _registrosFiltrados {
    return _registros.where((reg) {
      // Filtro por dispositivo
      final disp = reg['dispositivo']?.toString() ?? '';
      if (_dispositivoSeleccionado != 'Todos' && disp != _dispositivoSeleccionado) {
        return false;
      }

      // Filtro por severidad
      final sev = _evaluarSeveridad(
        reg['metrica']?.toString() ?? '',
        reg['valor'],
      );
      if (_filtroSeveridad == 'Graves' && sev != 'grave') return false;
      if (_filtroSeveridad == 'Levemente graves' && sev != 'leve') return false;
      if (_filtroSeveridad == 'Solo anormales' && sev == 'normal') return false;

      // Filtro por rango de fechas
      if (_rangoFechas != null && reg['timestamp'] != null) {
        final fecha = DateTime.tryParse(reg['timestamp'].toString());
        if (fecha != null) {
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
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dispositivos = <String>{
      'Todos',
      ..._registros.map((e) => e['dispositivo']?.toString() ?? '').where((e) => e.isNotEmpty),
    }.toList();

    final textoRango = _rangoFechas == null
        ? 'Rango de tiempo: Histórico completo'
        : '${_rangoFechas!.start.day}/${_rangoFechas!.start.month}/${_rangoFechas!.start.year} - '
            '${_rangoFechas!.end.day}/${_rangoFechas!.end.month}/${_rangoFechas!.end.year}';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Visor de Telemetría', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Registro Histórico de Dispositivos',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar registros',
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra de filtros: Rango de tiempo + Dispositivo + Severidad
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _seleccionarRangoTiempo,
                    icon: const Icon(Icons.date_range),
                    label: Text(textoRango),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  if (_rangoFechas != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _rangoFechas = null),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Limpiar fechas'),
                    ),
                  // Filtro por dispositivo
                  DropdownButton<String>(
                    value: dispositivos.contains(_dispositivoSeleccionado)
                        ? _dispositivoSeleccionado
                        : 'Todos',
                    dropdownColor: const Color(0xFF1E293B),
                    items: dispositivos
                        .map((d) => DropdownMenuItem(value: d, child: Text('Dispositivo: $d')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _dispositivoSeleccionado = val);
                    },
                  ),
                  // Filtro por estado/severidad
                  DropdownButton<String>(
                    value: _filtroSeveridad,
                    dropdownColor: const Color(0xFF1E293B),
                    items: const [
                      DropdownMenuItem(value: 'Todos', child: Text('Estado: Todos')),
                      DropdownMenuItem(value: 'Solo anormales', child: Text('Solo anormales')),
                      DropdownMenuItem(value: 'Graves', child: Text('Graves (Rojo)')),
                      DropdownMenuItem(
                        value: 'Levemente graves',
                        child: Text('Levemente graves (Amarillo)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _filtroSeveridad = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tabla histórica con barras de desplazamiento visibles (Horizontal y Vertical)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : Scrollbar(
                        controller: _verticalScroll,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalScroll,
                          scrollDirection: Axis.vertical,
                          child: Scrollbar(
                            controller: _horizontalScroll,
                            thumbVisibility: true,
                            trackVisibility: true,
                            notificationPredicate: (notif) => notif.depth == 1,
                            child: SingleChildScrollView(
                              controller: _horizontalScroll,
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFF0F172A),
                                ),
                                columns: const [
                                  DataColumn(label: Text('Fecha y Hora')),
                                  DataColumn(label: Text('Dispositivo')),
                                  DataColumn(label: Text('Métrica / Sensor')),
                                  DataColumn(label: Text('Valor Registrado')),
                                  DataColumn(label: Text('Unidad')),
                                  DataColumn(label: Text('Sector Patio')),
                                ],
                                rows: _registrosFiltrados.map((reg) {
                                  final regId = _generarRegistroId(reg);
                                  final metrica = reg['metrica']?.toString() ?? '-';
                                  final valor = reg['valor']?.toString() ?? '-';
                                  final severidad = _evaluarSeveridad(metrica, valor);
                                  final yaReportado = _idsYaReportados.contains(regId);

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(reg['timestamp']?.toString() ?? '-')),
                                      DataCell(Text(reg['dispositivo']?.toString() ?? '-')),
                                      DataCell(Text(metrica)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              valor,
                                              style: TextStyle(
                                                fontWeight: severidad != 'normal'
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: severidad == 'grave'
                                                    ? const Color(0xFFEF4444)
                                                    : severidad == 'leve'
                                                        ? const Color(0xFFF59E0B)
                                                        : Colors.white,
                                              ),
                                            ),
                                            // Ícono solo si es anormal y aún no ha sido reportado
                                            if (severidad != 'normal' && !yaReportado) ...[
                                              const SizedBox(width: 8),
                                              IconButton(
                                                tooltip: severidad == 'grave'
                                                    ? 'Problema grave: clic para reportar'
                                                    : 'Problema levemente grave: clic para reportar',
                                                icon: Icon(
                                                  Icons.warning_amber_rounded,
                                                  color: severidad == 'grave'
                                                      ? const Color(0xFFEF4444)
                                                      : const Color(0xFFF59E0B),
                                                ),
                                                onPressed: () =>
                                                    _reportarProblema(reg, regId, severidad),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(reg['unidad']?.toString() ?? '-')),
                                      DataCell(Text(reg['sector']?.toString() ?? 'Patio Norte')),
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