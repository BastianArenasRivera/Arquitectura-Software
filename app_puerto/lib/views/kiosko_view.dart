import 'package:flutter/material.dart';
import '../main.dart';

class KioskoLoaderView extends StatefulWidget {
  const KioskoLoaderView({super.key});
  @override
  State<KioskoLoaderView> createState() => _KioskoLoaderViewState();
}

class _KioskoLoaderViewState extends State<KioskoLoaderView> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const KioskoView()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 20),
            Text("Obteniendo datos mediante lectura RFID...", style: TextStyle(color: Colors.orange, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class KioskoView extends StatelessWidget {
  const KioskoView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Colors.black, automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SelectorView()), (route) => false),
            icon: const Icon(Icons.exit_to_app, color: Colors.red), label: const Text("Cerrar Vista", style: TextStyle(color: Colors.red))
          )
        ],
      ),
      body: Center(
        child: Container(
          width: 600, height: 350,
          decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black, width: 4)),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contactless, color: Colors.white, size: 40),
              SizedBox(height: 15),
              Text("VEHÍCULO DETECTADO (RFID)", style: TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold)),
              Text("PATENTE: ABCD-12", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Divider(color: Colors.white, thickness: 2, indent: 50, endIndent: 50, height: 30),
              Text("SU ANDÉN ASIGNADO ES:", style: TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold)),
              Text("ANDÉN B-4", style: TextStyle(color: Colors.white, fontSize: 55, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}