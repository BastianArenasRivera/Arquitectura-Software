import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';
import 'views/login_view.dart';
import 'views/kiosko_view.dart';

void main() => runApp(const PuertoApp());

class PuertoApp extends StatelessWidget {
  const PuertoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TOS - Terminal Logístico Portuario',
      theme: ThemeData.dark(),
      home: const SelectorView(),
    );
  }
}

class SelectorView extends StatefulWidget {
  const SelectorView({super.key});

  @override
  State<SelectorView> createState() => _SelectorViewState();
}

class _SelectorViewState extends State<SelectorView> {
  bool _apiOnline = false;
  bool _pgOnline = false;
  bool _influxOnline = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _verificarInfraestructura();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _verificarInfraestructura(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _verificarInfraestructura() async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/api/estado-sistema'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _apiOnline = data['fastapi'] == true;
          _pgOnline = data['postgres'] == true;
          _influxOnline = data['influx'] == true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _apiOnline = false;
          _pgOnline = false;
          _influxOnline = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06111E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1578575437130-527eed3abbec?auto=format&fit=crop&w=1920&q=80',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xDC06111E),
                  Color(0xEA06111E),
                  Color(0xF506111E),
                ],
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A192F).withValues(alpha: 0.9),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_boat, color: Color(0xFF0284C7), size: 22),
                        SizedBox(width: 10),
                        Text(
                          'SAN ANTONIO TERMINAL GATEWAY // TOS v4.2',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _buildStatusPill('API FastAPI', _apiOnline),
                        _buildStatusPill('PostgreSQL', _pgOnline),
                        _buildStatusPill('Telemetría IoT', _influxOnline),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Container(
                        padding: const EdgeInsets.all(34),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151F32).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Icon(
                                Icons.anchor,
                                color: Color(0xFFF59E0B),
                                size: 42,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'TERMINAL PORTUARIO',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Selecciona el módulo operativo para iniciar sesión',
                              style: TextStyle(fontSize: 14, color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            _buildModuloCard(
                              context: context,
                              titulo: 'Kiosko (Pórtico RFID)',
                              subtitulo: 'Control de acceso vehicular y lectura automática de tags',
                              icono: Icons.contactless,
                              colorAcento: const Color(0xFF22C55E),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const KioskoLoaderView()),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildModuloCard(
                              context: context,
                              titulo: 'Tablet (Operador Grúa)',
                              subtitulo: 'Terminal embarcado en cabina con sincronización offline',
                              icono: Icons.tablet_mac,
                              colorAcento: const Color(0xFFF59E0B),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginView(rolDestino: 'Tablet'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildModuloCard(
                              context: context,
                              titulo: 'Dashboard (Administrador)',
                              subtitulo: 'Centro de control operativo, mapa de patio y telemetría',
                              icono: Icons.dashboard,
                              colorAcento: const Color(0xFF0284C7),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginView(rolDestino: 'Administrador'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'RED LOGÍSTICA ENCRIPTADA • PUERTO SAN ANTONIO',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, bool online) {
    final Color color = online ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ${online ? "Online" : "Sin conexión"}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuloCard({
    required BuildContext context,
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color colorAcento,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1120).withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorAcento.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorAcento.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: colorAcento, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitulo,
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: colorAcento, size: 16),
          ],
        ),
      ),
    );
  }
}