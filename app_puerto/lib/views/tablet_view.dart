import 'package:flutter/material.dart';
import '../main.dart';

class TabletGruaView extends StatefulWidget {
  final String nombre;
  const TabletGruaView({super.key, required this.nombre});

  @override
  State<TabletGruaView> createState() => _TabletGruaViewState();
}

class _TabletGruaViewState extends State<TabletGruaView> {
  bool isOffline = false;

  void _notificarAccion(String mensaje, Color color) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
      ),
    );
  }

  void _mostrarMenuOpciones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "MENÚ OPERATIVO DE GRÚA",
              style: TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.build, color: Colors.amber),
              title: const Text("Reportar Falla Mecánica", style: TextStyle(color: Colors.white)),
              onTap: () => _notificarAccion(
                "Reporte de falla mecánica enviado a Central",
                Colors.orange[800]!,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.coffee, color: Colors.lightBlueAccent),
              title: const Text("Solicitar Pausa / Colación", style: TextStyle(color: Colors.white)),
              onTap: () => _notificarAccion(
                "Solicitud de colación enviada al Administrador",
                Colors.blue[800]!,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: const Text(
                "ACTIVAR PROTOCOLO DE EMERGENCIA",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () => _notificarAccion(
                "ALERTA DE EMERGENCIA ACTIVADA EN PATIO",
                Colors.red[900]!,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.precision_manufacturing, color: Colors.orange),
            const SizedBox(width: 10),
            Text(
              "OPERADOR: ${widget.nombre.toUpperCase()}",
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const SelectorView()),
              (route) => false,
            ),
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            label: const Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920, maxHeight: 560),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF22252A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3A3F47), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Barra superior de estado y menú
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => isOffline = !isOffline),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isOffline
                                ? Colors.amber.withValues(alpha: 0.15)
                                : Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isOffline ? Colors.amber : Colors.greenAccent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOffline ? Icons.wifi_off : Icons.wifi,
                                color: isOffline ? Colors.amber : Colors.greenAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isOffline
                                    ? "MODO OFFLINE - GUARDANDO LOCAL"
                                    : "MODO ONLINE - CONECTADO",
                                style: TextStyle(
                                  color: isOffline ? Colors.amber : Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF343A40),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _mostrarMenuOpciones(context),
                        icon: const Icon(Icons.menu),
                        label: const Text("MENÚ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tarjetas de tarea y ruta
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF181A1E),
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.inventory_2, color: Colors.orange, size: 36),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "TAREA ACTUAL ASIGNADA",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "MSC-U-123456 • 24 TON",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF181A1E),
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "ORIGEN: PATIO NORTE - CELDA 2",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "DESTINO: ANDÉN DE DESCARGA B-4",
                                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Plano esquemático del terminal + alerta de sector
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141B24),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF2D3B4E)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "PLANO OPERATIVO DEL TERMINAL",
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    Text(
                                      "RUTA ÓPTIMA ACTIVA",
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: Row(
                                    children: [
                                      _buildBloqueMapa("PATIO NORTE\n(Celda 2 - Origen)", Colors.blueAccent, true),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Icon(Icons.east, color: Colors.orange, size: 28),
                                      ),
                                      _buildBloqueMapa("VÍA CENTRAL\n(Tránsito Libre)", Colors.teal, false),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Icon(Icons.east, color: Colors.orange, size: 28),
                                      ),
                                      _buildBloqueMapa("ANDÉN B-4\n(Destino)", Colors.orange, true),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A1818),
                              border: Border.all(color: Colors.amber, width: 1.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 36),
                                SizedBox(height: 8),
                                Text(
                                  "ALERTA DE SECTOR",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "ZONA SUR\nCONGESTIONADA\n(EVITAR TRÁNSITO)",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Botón principal de confirmación
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EsperandoTareaView(nombre: widget.nombre),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 28),
                      label: const Text(
                        "CONFIRMAR AGARRE DEL CONTENEDOR",
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBloqueMapa(String titulo, Color color, bool destacado) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: destacado ? 0.2 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: destacado ? 2 : 1),
        ),
        child: Center(
          child: Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class EsperandoTareaView extends StatelessWidget {
  final String nombre;
  const EsperandoTareaView({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        automaticallyImplyLeading: false,
        title: Text(
          "OPERADOR: ${nombre.toUpperCase()}",
          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 28),
            const Text(
              "CONTENEDOR CONFIRMADO",
              style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "ESPERANDO SIGUIENTE TAREA...",
              style: TextStyle(
                color: Colors.orange,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 44),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                  ),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => TabletGruaView(nombre: nombre)),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    "Simular Nueva Tarea",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                  ),
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SelectorView()),
                    (route) => false,
                  ),
                  icon: const Icon(Icons.exit_to_app, color: Colors.white),
                  label: const Text(
                    "Volver al Inicio",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}