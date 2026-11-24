import 'package:flutter/material.dart';
import 'views/login_view.dart';
import 'views/kiosko_view.dart';

void main() => runApp(const PuertoApp());

class PuertoApp extends StatelessWidget {
  const PuertoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema Logístico Portuario',
      theme: ThemeData.dark(),
      home: const SelectorView(),
    );
  }
}

class SelectorView extends StatelessWidget {
  const SelectorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF161D29),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.anchor, color: Colors.orange, size: 42),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "TERMINAL PORTUARIO",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Selecciona el módulo operativo",
                    style: TextStyle(fontSize: 14, color: Colors.white60),
                  ),
                  const SizedBox(height: 28),
                  _buildBtn(
                    context,
                    "Kiosko (Pórtico RFID)",
                    Icons.contactless,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KioskoLoaderView())),
                  ),
                  const SizedBox(height: 14),
                  _buildBtn(
                    context,
                    "Tablet (Operador Grúa)",
                    Icons.tablet_mac,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginView(rolDestino: 'Tablet'))),
                  ),
                  const SizedBox(height: 14),
                  _buildBtn(
                    context,
                    "Dashboard (Administrador)",
                    Icons.dashboard,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginView(rolDestino: 'Administrador'))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBtn(BuildContext context, String texto, IconData icono, VoidCallback accion) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF232D3F),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.white12),
          ),
        ),
        onPressed: accion,
        icon: Icon(icono, color: Colors.orange, size: 24),
        label: Text(texto, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }
}