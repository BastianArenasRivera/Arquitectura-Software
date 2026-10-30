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
      title: 'Sistema Logístico',
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
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 400, padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange, width: 2)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("SELECCIONAR VISTA:", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 30),
              _buildBtn(context, "Kiosko (Pórtico)", Icons.contactless, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KioskoLoaderView()))),
              const SizedBox(height: 15),
              _buildBtn(context, "Tablet (Grúa)", Icons.tablet_mac, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginView(rolDestino: 'Tablet')))),
              const SizedBox(height: 15),
              _buildBtn(context, "Dashboard (Admin)", Icons.dashboard, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginView(rolDestino: 'Administrador')))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBtn(BuildContext context, String texto, IconData icono, VoidCallback accion) {
    return SizedBox(
      width: double.infinity, height: 60,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
        onPressed: accion, icon: Icon(icono, color: Colors.orange), label: Text(texto, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}