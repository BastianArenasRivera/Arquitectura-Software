import 'package:flutter/material.dart';
import '../main.dart';

class TabletGruaView extends StatefulWidget {
  final String nombre;
  const TabletGruaView({super.key, required this.nombre});

  @override
  State<TabletGruaView> createState() => _TabletGruaViewState();
}

class _TabletGruaViewState extends State<TabletGruaView> {
  bool isOffline = false; // Variable para controlar el estado

  void _mostrarMenuOpciones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("MENÚ OPERATIVO", style: TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.grey),
            ListTile(leading: const Icon(Icons.build, color: Colors.white), title: const Text("Reportar Falla Mecánica", style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.coffee, color: Colors.white), title: const Text("Solicitar Pausa / Colación", style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.warning, color: Colors.red), title: const Text("ACTIVAR PROTOCOLO DE EMERGENCIA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900], automaticallyImplyLeading: false,
        title: Text("OPERADOR: ${widget.nombre.toUpperCase()}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SelectorView()), (route) => false),
            icon: const Icon(Icons.exit_to_app, color: Colors.red), label: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red))
          )
        ],
      ),
      body: Center(
        child: Container(
          width: 800, height: 480, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 20)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Etiqueta Dinámica Online/Offline (Presionable para demostrar en video)
                  GestureDetector(
                    onTap: () => setState(() => isOffline = !isOffline),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
                      decoration: BoxDecoration(color: isOffline ? Colors.black : Colors.green[800], borderRadius: BorderRadius.circular(5), border: Border.all(color: isOffline ? Colors.yellow : Colors.green, width: 2)), 
                      child: Text(
                        isOffline ? "! MODO OFFLINE - GUARDANDO LOCAL..." : "✓ MODO ONLINE - CONECTADO", 
                        style: TextStyle(color: isOffline ? Colors.yellow : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                      )
                    ),
                  ),
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]), onPressed: () => _mostrarMenuOpciones(context), child: const Text("MENU", style: TextStyle(color: Colors.white, fontSize: 18)))
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(10)), child: const Row(children: [Icon(Icons.directions_boat, color: Colors.grey, size: 40), SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("TAREA ACTUAL ASIGNADA:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("MSC-U-123456 | PESO: 24 TONELADAS", style: TextStyle(color: Colors.grey))])]))),
                  const SizedBox(width: 10),
                  Expanded(child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(10)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("ORIGEN: PATIO NORTE, CELDA 2", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("DESTINO: ANDÉN B-4", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Container(decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)), child: const Center(child: Text("[MAPA SATELITAL DEL PUERTO]", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 18))))),
                    const SizedBox(width: 10),
                    Expanded(flex: 1, child: Container(decoration: BoxDecoration(color: const Color(0xFF222222), border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(10)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("MAPA DEL SECTOR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 20), Text("/// ZONA SUR\nCONGESTIONADA\n(EVITAR) ///", textAlign: TextAlign.center, style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 14))]))),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity, height: 60, 
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => EsperandoTareaView(nombre: widget.nombre))), 
                  child: const Text("CONFIRMAR AGARRE DEL CONTENEDOR", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2))
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Nueva vista al confirmar la tarea
class EsperandoTareaView extends StatelessWidget {
  final String nombre;
  const EsperandoTareaView({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900], automaticallyImplyLeading: false,
        title: Text("OPERADOR: ${nombre.toUpperCase()}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 30),
            const Text("ESPERANDO SIGUIENTE TAREA...", style: TextStyle(color: Colors.orange, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
              onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SelectorView()), (route) => false),
              icon: const Icon(Icons.exit_to_app, color: Colors.white), label: const Text("Volver al Inicio", style: TextStyle(color: Colors.white, fontSize: 18))
            )
          ],
        ),
      ),
    );
  }
}