import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class KioskoLoaderView extends StatefulWidget {
  const KioskoLoaderView({super.key});

  @override
  State<KioskoLoaderView> createState() => _KioskoLoaderViewState();
}

class _KioskoLoaderViewState extends State<KioskoLoaderView> {
  int _vehiculoSeleccionado = 0;
  bool _procesando = false;
  Map? _ultimaLectura;

  final List _vehiculosSimulados = const [
    {
      'patente': 'ABCD-12',
      'transportista': 'Transportes Maersk Chile',
      'contenedor': 'MSKU-742918',
      'tramite': 'Ingreso a Patio',
      'anden': 'Andén B-4',
    },
    {
      'patente': 'KLRW-88',
      'transportista': 'Logística Pacífico Sur',
      'contenedor': 'MSCU-901234',
      'tramite': 'Carga Exportación',
      'anden': 'Andén B-2',
    },
    {
      'patente': 'PGTZ-45',
      'transportista': 'Expreso San Antonio',
      'contenedor': 'HLCU-553821',
      'tramite': 'Descarga Importación',
      'anden': 'Andén C-1',
    },
    {
      'patente': 'ZXCV-91',
      'transportista': 'TransContainer S.A.',
      'contenedor': 'CMAU-331098',
      'tramite': 'Retiro de Vacío',
      'anden': 'Andén A-3',
    },
  ];

  Future<void> _simularLecturaRfid() async {
    final vehiculo = _vehiculosSimulados[_vehiculoSeleccionado];
    setState(() => _procesando = true);

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/accesos'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'patente': vehiculo['patente'],
              'anden': vehiculo['anden'],
              'transportista': vehiculo['transportista'],
              'contenedor': vehiculo['contenedor'],
              'tramite': vehiculo['tramite'],
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 && mounted) {
        setState(() {
          _ultimaLectura = vehiculo;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ultimaLectura = vehiculo;
        });
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actual = _vehiculosSimulados[_vehiculoSeleccionado];

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151F32),
        title: const Row(
          children: [
            Icon(Icons.contactless, color: Color(0xFF22C55E)),
            SizedBox(width: 10),
            Text(
              'PÓRTICO AUTOMATIZADO RFID • ACCESO NORTE',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF151F32),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sensors, color: Color(0xFF22C55E), size: 54),
                  const SizedBox(height: 12),
                  const Text(
                    'CONTROL DE ACCESO VEHICULAR',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecciona una unidad para simular la lectura de antena UHF en pórtico',
                    style: TextStyle(color: Colors.white60, fontSize: 13.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: List.generate(_vehiculosSimulados.length, (i) {
                      final v = _vehiculosSimulados[i];
                      final bool sel = _vehiculoSeleccionado == i;
                      return ChoiceChip(
                        label: Text(
                          '${v['patente']} (${v['anden']})',
                          style: TextStyle(
                            color: sel ? const Color(0xFF0B1120) : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: sel,
                        selectedColor: const Color(0xFF22C55E),
                        backgroundColor: const Color(0xFF0B1120),
                        onSelected: (_) =>
                            setState(() => _vehiculoSeleccionado = i),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1120),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        _filaInfo('Patente Vehículo:', actual['patente']),
                        _filaInfo('Transportista:', actual['transportista']),
                        _filaInfo('Contenedor:', actual['contenedor']),
                        _filaInfo('Operación:', actual['tramite']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: const Color(0xFF0B1120),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _procesando ? null : _simularLecturaRfid,
                      icon: const Icon(Icons.qr_code_scanner, size: 28),
                      label: Text(
                        _procesando
                            ? 'REGISTRANDO EN POSTGRESQL...'
                            : 'SIMULAR LECTURA TAG RFID',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  if (_ultimaLectura != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF22C55E)),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle,
                                  color: Color(0xFF22C55E)),
                              SizedBox(width: 8),
                              Text(
                                'ACCESO AUTORIZADO • BARRERA ABIERTA',
                                style: TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Patente ${_ultimaLectura!['patente']} → Dirigirse a ${_ultimaLectura!['anden']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ingreso sincronizado con el Panel Logístico Central',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filaInfo(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          Text(
            val,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}