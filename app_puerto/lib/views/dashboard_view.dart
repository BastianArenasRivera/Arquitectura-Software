import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../main.dart';
import 'influx_view.dart';

class DashboardAdminView extends StatefulWidget {
  const DashboardAdminView({super.key});
  @override
  State<DashboardAdminView> createState() => _DashboardAdminViewState();
}

class _DashboardAdminViewState extends State<DashboardAdminView> {
  final ScrollController _scrollController = ScrollController();
  
  var alertas = [
    {"texto": "Camión ABDC-12 asignado a B-4", "color": Colors.blue[100], "icono": Icons.info, "iconColor": Colors.blue},
    {"texto": "Congestión Alta en sector Sur.", "color": Colors.red[100], "icono": Icons.error, "iconColor": Colors.red},
  ];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (timer) {
      var nuevosEventos = [
        {"texto": "Grúa requiere mantenimiento preventivo", "color": Colors.orange[100], "icono": Icons.warning, "iconColor": Colors.orange},
        {"texto": "Lectura RFID exitosa en Pórtico Norte", "color": Colors.green[100], "icono": Icons.check_circle, "iconColor": Colors.green},
        {"texto": "Retraso detectado en Andén C-3", "color": Colors.red[100], "icono": Icons.error, "iconColor": Colors.red},
      ];
      setState(() {
        alertas.insert(0, nuevosEventos[Random().nextInt(nuevosEventos.length)]);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _abrirNotificaciones(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.notifications_active, color: Colors.blue), SizedBox(width: 10), Text("Solicitudes y Alertas")]),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.coffee, color: Colors.brown, size: 30),
                title: const Text("Joaquín (Grúa 2) solicita colación.", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Hace 2 minutos"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => Navigator.pop(context)),
                    IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.red, size: 30),
                title: const Text("EMERGENCIA: Alerta de Falla Mecánica", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                subtitle: const Text("Grúa 5 - Patio Sur"),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("REVISAR", style: TextStyle(color: Colors.white))
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar Panel"))],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F6F8), 
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0A2540), foregroundColor: Colors.white)
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Row(children: [Icon(Icons.precision_manufacturing), SizedBox(width: 10), Text('Panel Logístico Central', style: TextStyle(fontWeight: FontWeight.bold))]),
          actions: [
            IconButton(icon: const Icon(Icons.notifications, color: Colors.white, size: 28), onPressed: () => _abrirNotificaciones(context)),
            const SizedBox(width: 15), 
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilAdminView())),
              child: const Row(
                children: [
                  Icon(Icons.account_circle, size: 30, color: Colors.white), 
                  SizedBox(width: 8), 
                  Text("Admin", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(width: 20),
            TextButton.icon(
              onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SelectorView()), (route) => false), 
              icon: const Icon(Icons.exit_to_app, color: Colors.redAccent), label: const Text("Salir", style: TextStyle(color: Colors.redAccent))
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("MÉTRICAS EN TIEMPO REAL:", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _buildMetricaCard(Icons.local_shipping, "Camiones en patio: 45"),
                    _buildMetricaCard(Icons.precision_manufacturing, "Grúas Activas: 12"),
                    const SizedBox(height: 20),
                    const Text("PANEL DE ALERTAS (SCROLL):", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[300]!)),
                        child: Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(10),
                            itemCount: alertas.length,
                            itemBuilder: (context, index) {
                              var alerta = alertas[index];
                              return _buildAlertaCard(alerta["texto"], alerta["color"], alerta["icono"], alerta["iconColor"]);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[400]!, width: 2)),
                        child: Column(
                          children: [
                            Expanded(child: _buildZonaPatio("PATIO NORTE", Colors.green[200]!, "Ocupación: 92% (Crítico)")),
                            Container(height: 60, color: Colors.grey[800], child: const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Icon(Icons.local_shipping, color: Colors.white, size: 30), Text("VÍA DE TRÁNSITO Y ANDENES DE DESCARGA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)), Icon(Icons.directions_boat, color: Colors.white, size: 30)])),
                            Expanded(child: _buildZonaPatio("PATIO SUR", Colors.grey[300]!, "Ocupación: 45% (Despejado)")),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: _buildAccionBtn(Icons.storage, "Ver Datos\nInfluxDB", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfluxDataView())))),
                        const SizedBox(width: 10),
                        Expanded(child: _buildAccionBtn(Icons.auto_graph, "Forzar Optimización\nMatemática", _forzarOptimizacion)),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _forzarOptimizacion() {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Row(children: [Icon(Icons.auto_graph, color: Colors.green), SizedBox(width: 10), Text("Optimización Matemática")]), content: const Text("Algoritmo de asignación ejecutado con éxito.\n\nSe han reasignado 3 grúas del Patio Sur al Patio Norte para aliviar la congestión."), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Aceptar"))]));
  }

  Widget _buildZonaPatio(String titulo, Color color, String estado) {
    return Container(width: double.infinity, color: color, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(titulo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(20)), child: Text(estado, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))]));
  }

  Widget _buildMetricaCard(dynamic icono, dynamic texto) {
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: Colors.grey[300]!)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), child: Row(children: [Icon(icono, size: 40, color: const Color(0xFF1B2A47)), const SizedBox(width: 20), Text(texto, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16))])));
  }

  Widget _buildAlertaCard(dynamic texto, dynamic bgColor, dynamic icono, dynamic iconColor) {
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)), child: Row(children: [CircleAvatar(backgroundColor: iconColor, radius: 15, child: Icon(icono, color: Colors.white, size: 20)), const SizedBox(width: 15), Expanded(child: Text(texto, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)))]));
  }

  Widget _buildAccionBtn(dynamic icono, dynamic texto, VoidCallback accion) {
    return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B2A47), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: accion, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icono, color: Colors.white, size: 40), const SizedBox(width: 15), Text(texto, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center)]));
  }
}

// Perfil de Administrador Actualizado a StatefulWidget para manejar estados
class PerfilAdminView extends StatefulWidget {
  const PerfilAdminView({super.key});

  @override
  State<PerfilAdminView> createState() => _PerfilAdminViewState();
}

class _PerfilAdminViewState extends State<PerfilAdminView> {
  bool _ocultarClave = true;
  String _fotoUrl = "https://cdn-icons-png.flaticon.com/512/3135/3135715.png"; // Avatar inicial

  // Controladores para que el texto no se borre al presionar el ojito
  final _userCtrl = TextEditingController(text: "admin");
  final _passCtrl = TextEditingController(text: "Admin123");
  final _rutCtrl = TextEditingController(text: "19.234.567-8");
  final _phoneCtrl = TextEditingController(text: "+56 9 8765 4321");

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _rutCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _simularCambioFoto() {
    setState(() {
      // Cambia la imagen por otra para demostrar la interacción en el video
      _fotoUrl = "https://cdn-icons-png.flaticon.com/512/4140/4140037.png";
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto de perfil actualizada"), backgroundColor: Colors.blue));
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(title: const Text("Perfil del Administrador", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0A2540), iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: Container(
          width: 500, padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[300]!), boxShadow: [BoxShadow(color: Colors.grey[300]!, blurRadius: 10)]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar con botón de cámara simulado
              GestureDetector(
                onTap: _simularCambioFoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(radius: 50, backgroundImage: NetworkImage(_fotoUrl), backgroundColor: Colors.grey[200]),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF0A2540), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                style: textStyle, controller: _userCtrl,
                decoration: const InputDecoration(labelText: "Nombre de Usuario", labelStyle: TextStyle(color: Colors.black87), prefixIcon: Icon(Icons.person, color: Colors.black87)), 
              ),
              const SizedBox(height: 15),
              TextField(
                style: textStyle, controller: _passCtrl,
                obscureText: _ocultarClave,
                decoration: InputDecoration(
                  labelText: "Nueva Contraseña", labelStyle: const TextStyle(color: Colors.black87), prefixIcon: const Icon(Icons.lock, color: Colors.black87),
                  // Botón de visualización de contraseña
                  suffixIcon: IconButton(
                    icon: Icon(_ocultarClave ? Icons.visibility : Icons.visibility_off, color: Colors.black87),
                    onPressed: () => setState(() => _ocultarClave = !_ocultarClave),
                  )
                ), 
              ),
              const SizedBox(height: 15),
              TextField(
                style: textStyle, controller: _rutCtrl,
                decoration: const InputDecoration(labelText: "RUT (Identificación)", labelStyle: TextStyle(color: Colors.black87), prefixIcon: Icon(Icons.badge, color: Colors.black87)), 
              ),
              const SizedBox(height: 15),
              TextField(
                style: textStyle, controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: "Número de Teléfono", labelStyle: TextStyle(color: Colors.black87), prefixIcon: Icon(Icons.phone, color: Colors.black87)), 
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Datos actualizados correctamente"), backgroundColor: Colors.green));
                    Navigator.pop(context);
                  },
                  child: const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                )
              )
            ],
          ),
        ),
      ),
    );
  }
}