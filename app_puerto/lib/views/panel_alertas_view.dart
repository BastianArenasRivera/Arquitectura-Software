import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// Vista de analítica anual de fallas y gestión de reportes de patio y dispositivos
class PanelAlertasView extends StatefulWidget {
  final List alertasPatio;
  const PanelAlertasView({super.key, this.alertasPatio = const []});
  @override
  State<PanelAlertasView> createState() => _PanelAlertasViewState();
}

class _PanelAlertasViewState extends State<PanelAlertasView> {
  final ScrollController _patioScrollCtrl = ScrollController();
  final ScrollController _reportesScrollCtrl = ScrollController();

  int _anioSeleccionado = DateTime.now().year;
  List<int> _aniosDisponibles = [2026, 2025, 2024];
  List _datosMensuales = [];
  List _reportesDispositivos = [];
  bool _cargando = true;

  final List<String> _nombresMeses = const [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  @override
  void initState() {
    super.initState();
    _cargarPanel();
  }

  @override
  void dispose() {
    _patioScrollCtrl.dispose();
    _reportesScrollCtrl.dispose();
    super.dispose();
  }

  // Obtiene desde FastAPI el resumen mensual por año y la lista de reportes registrados
  Future<void> _cargarPanel() async {
    setState(() => _cargando = true);
    try {
      final resAnual = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/reportes-dispositivos/resumen-anual?anio=$_anioSeleccionado',
        ),
      );
      if (resAnual.statusCode == 200) {
        final data = jsonDecode(resAnual.body);
        final anios = (data['anios_disponibles'] as List)
            .map((e) => e as int)
            .toList();
        _aniosDisponibles = {...anios, 2026, 2025, 2024}.toList()
          ..sort((a, b) => b.compareTo(a));
        _datosMensuales = List.from(data['meses']);
      }

      final resReportes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/reportes-dispositivos'),
      );
      if (resReportes.statusCode == 200) {
        _reportesDispositivos = List.from(jsonDecode(resReportes.body));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Marca un reporte como resuelto en PostgreSQL
  Future<void> _marcarResuelto(int reporteId) async {
    try {
      final res = await http.put(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/reportes-dispositivos/$reporteId/resolver',
        ),
      );
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte marcado como resuelto'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        _cargarPanel();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final int maxProblemasMes = _datosMensuales.fold<int>(
      1,
      (prev, m) => (m['total'] as int) > prev ? (m['total'] as int) : prev,
    );

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
            'Panel de Alertas y Analítica',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              onPressed: _cargarPanel,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
          ],
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tarjeta superior con gráfico de barras apiladas por mes y selector de año
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Problemas de Dispositivos por Mes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A2540),
                                ),
                              ),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F4F8),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF0A2540),
                                    width: 1.5,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _anioSeleccionado,
                                    dropdownColor: const Color(0xFF0A2540),
                                    borderRadius: BorderRadius.circular(10),
                                    iconEnabledColor: const Color(0xFF0A2540),
                                    icon: const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Color(0xFF0A2540),
                                      ),
                                    ),
                                    selectedItemBuilder: (context) =>
                                        _aniosDisponibles
                                            .map(
                                              (anio) => Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  'Año $anio',
                                                  style: const TextStyle(
                                                    color: Color(0xFF0A2540),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    items: _aniosDisponibles
                                        .map(
                                          (anio) => DropdownMenuItem<int>(
                                            value: anio,
                                            child: Text(
                                              'Año $anio',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (nuevoAnio) {
                                      if (nuevoAnio != null) {
                                        setState(() =>
                                            _anioSeleccionado = nuevoAnio);
                                        _cargarPanel();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(Icons.square,
                                  size: 13, color: Color(0xFFDC2626)),
                              SizedBox(width: 4),
                              Text('Grave',
                                  style: TextStyle(
                                      color: Colors.black87, fontSize: 12)),
                              SizedBox(width: 16),
                              Icon(Icons.square,
                                  size: 13, color: Color(0xFFD97706)),
                              SizedBox(width: 4),
                              Text(
                                'Levemente grave',
                                style: TextStyle(
                                    color: Colors.black87, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 210,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(12, (index) {
                                final item = index < _datosMensuales.length
                                    ? _datosMensuales[index]
                                    : {'graves': 0, 'leves': 0, 'total': 0};
                                final int graves = item['graves'] as int;
                                final int leves = item['leves'] as int;
                                final int total = item['total'] as int;
                                const double altoMax = 150.0;
                                final double altoGrave =
                                    (graves / maxProblemasMes) * altoMax;
                                final double altoLeve =
                                    (leves / maxProblemasMes) * altoMax;

                                return Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$total',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Tooltip(
                                        message:
                                            '${_nombresMeses[index]} $_anioSeleccionado: $graves graves, $leves leves',
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: altoGrave,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFDC2626),
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                  top: Radius.circular(4),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 24,
                                              height: altoLeve,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD97706),
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                  top: altoGrave == 0
                                                      ? const Radius.circular(4)
                                                      : Radius.zero,
                                                ),
                                              ),
                                            ),
                                            if (total == 0)
                                              Container(
                                                width: 24,
                                                height: 4,
                                                color: Colors.grey[300],
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _nombresMeses[index],
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Dos columnas inferiores: Alertas de Patio y Reportes de Dispositivos
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildSeccionAlertasPatio()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSeccionReportesDispositivos()),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSeccionAlertasPatio() {
    final listaPatio = widget.alertasPatio.isNotEmpty
        ? widget.alertasPatio
        : [
            {
              'texto': 'Congestión Alta en Bloque A (Reefer).',
              'color': const Color(0xFFFEE2E2),
              'icono': Icons.error,
              'iconColor': const Color(0xFFDC2626),
            },
            {
              'texto': 'Grúa RTG-02 requiere mantenimiento preventivo',
              'color': const Color(0xFFFEF3C7),
              'icono': Icons.warning,
              'iconColor': const Color(0xFFD97706),
            },
          ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_shipping, color: Color(0xFF0A2540)),
                  SizedBox(width: 8),
                  Text(
                    'Alertas de Patio',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2540),
                    ),
                  ),
                ],
              ),
              Text(
                '${listaPatio.length} alertas',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          SizedBox(
            height: 340,
            child: Scrollbar(
              controller: _patioScrollCtrl,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              thickness: 8,
              child: ListView.builder(
                controller: _patioScrollCtrl,
                padding: const EdgeInsets.only(right: 12),
                itemCount: listaPatio.length,
                itemBuilder: (context, index) {
                  final alerta = listaPatio[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: alerta['color'] ?? Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: alerta['iconColor'] ?? Colors.blue,
                          radius: 15,
                          child: Icon(
                            alerta['icono'] ?? Icons.info,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            alerta['texto']?.toString() ?? '',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildSeccionReportesDispositivos() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sensors_off, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Text(
                    'Reportes de Dispositivos',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2540),
                    ),
                  ),
                ],
              ),
              Text(
                '${_reportesDispositivos.length} reportes',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          SizedBox(
            height: 340,
            child: _reportesDispositivos.isEmpty
                ? const Center(
                    child: Text(
                      'Aún no se han reportado anomalías desde el Visor de Telemetría.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : Scrollbar(
                    controller: _reportesScrollCtrl,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    thickness: 8,
                    child: ListView.builder(
                      controller: _reportesScrollCtrl,
                      padding: const EdgeInsets.only(right: 12),
                      itemCount: _reportesDispositivos.length,
                      itemBuilder: (context, index) {
                        final rep = _reportesDispositivos[index];
                        final bool esGrave = rep['severidad'] == 'grave';
                        final bool resuelto = rep['estado'] == 'resuelto';
                        final Color color = resuelto
                            ? const Color(0xFF16A34A)
                            : esGrave
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFD97706);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: resuelto
                                ? const Color(0xFFF0FDF4)
                                : esGrave
                                    ? const Color(0xFFFEF2F2)
                                    : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: color.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                resuelto
                                    ? Icons.check_circle
                                    : Icons.warning_rounded,
                                color: color,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${rep['dispositivo']} (${rep['metrica']})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Valor: ${rep['valor']} • ${rep['fecha_registro']}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!resuelto)
                                TextButton(
                                  onPressed: () =>
                                      _marcarResuelto(rep['id'] as int),
                                  child: const Text(
                                    'Resolver',
                                    style: TextStyle(
                                      color: Color(0xFF0284C7),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  resuelto
                                      ? 'Resuelto'
                                      : esGrave
                                          ? 'Grave'
                                          : 'Leve',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
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
    );
  }
}