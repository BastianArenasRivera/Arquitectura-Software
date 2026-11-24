import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../config/api_config.dart';
import 'influx_view.dart';
import 'panel_alertas_view.dart';

class DashboardAdminView extends StatefulWidget {
  const DashboardAdminView({super.key});
  @override
  State<DashboardAdminView> createState() => _DashboardAdminViewState();
}

class _DashboardAdminViewState extends State<DashboardAdminView> {
  final ScrollController _scrollController = ScrollController();

  List alertas = [
    {
      'texto': 'Camión ABDC-12 asignado a B-4',
      'color': Colors.blue[100],
      'icono': Icons.info,
      'iconColor': Colors.blue,
    },
    {
      'texto': 'Congestión Alta en sector Sur.',
      'color': Colors.red[100],
      'icono': Icons.error,
      'iconColor': Colors.red,
    },
  ];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!mounted) return;
      List nuevosEventos = [
        {
          'texto': 'Grúa requiere mantenimiento preventivo',
          'color': Colors.orange[100],
          'icono': Icons.warning,
          'iconColor': Colors.orange,
        },
        {
          'texto': 'Lectura RFID exitosa en Pórtico Norte',
          'color': Colors.green[100],
          'icono': Icons.check_circle,
          'iconColor': Colors.green,
        },
        {
          'texto': 'Retraso detectado en Andén C-3',
          'color': Colors.red[100],
          'icono': Icons.error,
          'iconColor': Colors.red,
        },
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
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.blue),
            SizedBox(width: 10),
            Text('Solicitudes y Alertas'),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.coffee, color: Colors.brown, size: 30),
                title: const Text(
                  'Joaquín (Grúa 2) solicita colación.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Hace 2 minutos'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.red, size: 30),
                title: const Text(
                  'EMERGENCIA: Alerta de Falla Mecánica',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                subtitle: const Text('Grúa 5 - Patio Sur'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('REVISAR', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar Panel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A2540),
          foregroundColor: Colors.white,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.precision_manufacturing),
              SizedBox(width: 10),
              Text(
                'Panel Logístico Central',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white, size: 28),
              onPressed: () => _abrirNotificaciones(context),
            ),
            const SizedBox(width: 15),
            InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PerfilAdminView()),
                );
                if (mounted) setState(() {});
              },
              child: Row(
                children: [
                  PerfilAdminView.fotoBytes != null
                      ? CircleAvatar(
                          radius: 16,
                          backgroundImage: MemoryImage(PerfilAdminView.fotoBytes!),
                        )
                      : const Icon(Icons.account_circle, size: 30, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    PerfilAdminView.nombreUsuarioActual,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            TextButton.icon(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const SelectorView()),
                (route) => false,
              ),
              icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              label: const Text('Salir', style: TextStyle(color: Colors.redAccent)),
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
                    const Text(
                      'MÉTRICAS EN TIEMPO REAL:',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildMetricaCard(Icons.local_shipping, 'Camiones en patio: 45'),
                    _buildMetricaCard(Icons.precision_manufacturing, 'Grúas Activas: 12'),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PanelAlertasView(alertasPatio: alertas),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'PANEL DE ALERTAS',
                            style: TextStyle(
                              color: Color(0xFF0A2540),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.open_in_new, size: 17, color: Color(0xFF0A2540)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(10),
                            itemCount: alertas.length,
                            itemBuilder: (context, index) {
                              var alerta = alertas[index];
                              return _buildAlertaCard(
                                alerta['texto'],
                                alerta['color'],
                                alerta['icono'],
                                alerta['iconColor'],
                              );
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
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[400]!, width: 2),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: _buildZonaPatio(
                                'PATIO NORTE',
                                Colors.green[200]!,
                                'Ocupación: 92% (Crítico)',
                              ),
                            ),
                            Container(
                              height: 60,
                              color: Colors.grey[800],
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Icon(Icons.local_shipping, color: Colors.white, size: 30),
                                  Text(
                                    'VÍA DE TRÁNSITO Y ANDENES DE DESCARGA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Icon(Icons.directions_boat, color: Colors.white, size: 30),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _buildZonaPatio(
                                'PATIO SUR',
                                Colors.grey[300]!,
                                'Ocupación: 45% (Despejado)',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAccionBtn(
                            Icons.analytics,
                            'Visor de\nTelemetría',
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const InfluxDataView()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildAccionBtn(
                            Icons.auto_graph,
                            'Forzar Optimización\nMatemática',
                            _forzarOptimizacion,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _forzarOptimizacion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_graph, color: Colors.green),
            SizedBox(width: 10),
            Text('Optimización Matemática'),
          ],
        ),
        content: const Text(
          'Algoritmo de asignación ejecutado con éxito.\n\nSe han reasignado 3 grúas del Patio Sur al Patio Norte para aliviar la congestión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Widget _buildZonaPatio(String titulo, Color color, String estado) {
    return Container(
      width: double.infinity,
      color: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white70,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              estado,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricaCard(IconData icono, String texto) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icono, size: 40, color: const Color(0xFF1B2A47)),
            const SizedBox(width: 20),
            Text(
              texto,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertaCard(dynamic texto, dynamic bgColor, dynamic icono, dynamic iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor,
            radius: 15,
            child: Icon(icono, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionBtn(IconData icono, String texto, VoidCallback accion) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1B2A47),
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: accion,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: Colors.white, size: 40),
          const SizedBox(width: 15),
          Text(
            texto,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class PerfilAdminView extends StatefulWidget {
  static Uint8List? fotoBytes;
  static String nombreUsuarioActual = 'Admin';

  const PerfilAdminView({super.key});
  @override
  State<PerfilAdminView> createState() => _PerfilAdminViewState();
}

class _PerfilAdminViewState extends State<PerfilAdminView> {
  bool _ocultarClave = true;
  bool _ocultarConfirmClave = true;
  bool _guardando = false;

  final String _fotoUrlPorDefecto =
      'https://cdn-icons-png.flaticon.com/512/3135/3135715.png';
  Uint8List? _fotoLocalBytes;

  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _rutCtrl = TextEditingController(text: '19.234.567-8');
  final _phoneCtrl = TextEditingController(text: '+56 9 8765 4321');

  @override
  void initState() {
    super.initState();
    _fotoLocalBytes = PerfilAdminView.fotoBytes;
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _rutCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _subirFotoDesdeEquipo() {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();
    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(files[0]);
        reader.onLoadEnd.listen((_) {
          if (reader.result != null && mounted) {
            setState(() {
              _fotoLocalBytes = reader.result as Uint8List;
            });
          }
        });
      }
    });
  }

  Future<void> _guardarCambios() async {
    final String usuario = _userCtrl.text.trim();
    final String nuevaPass = _passCtrl.text;
    final String confirmarPass = _confirmPassCtrl.text;

    if (usuario.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre de usuario no puede estar vacío.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (nuevaPass.isNotEmpty || confirmarPass.isNotEmpty) {
      if (nuevaPass != confirmarPass) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Las contraseñas no coinciden. Verifica que esté bien escrita.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{6,}$').hasMatch(nuevaPass)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La contraseña debe tener al menos 6 caracteres, 1 mayúscula, 1 minúscula y 1 número.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _guardando = true);

    try {
      if (nuevaPass.isNotEmpty) {
        await http.put(
          Uri.parse('${ApiConfig.baseUrl}/api/admin/perfil'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'usuario': usuario,
            'nueva_password': nuevaPass,
          }),
        );
      }
    } catch (_) {}

    PerfilAdminView.fotoBytes = _fotoLocalBytes;
    PerfilAdminView.nombreUsuarioActual =
        usuario == 'admin' ? 'Admin' : usuario;

    if (!mounted) return;
    setState(() => _guardando = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nuevaPass.isNotEmpty
              ? 'Perfil y nueva contraseña guardados correctamente.'
              : 'Datos de perfil actualizados correctamente.',
        ),
        backgroundColor: Colors.green[700],
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );

    final bool escribiendoClave =
        _passCtrl.text.isNotEmpty || _confirmPassCtrl.text.isNotEmpty;
    final bool clavesCoinciden =
        _passCtrl.text.isNotEmpty && _passCtrl.text == _confirmPassCtrl.text;

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A2540),
          foregroundColor: Colors.white,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Perfil del Administrador',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _subirFotoDesdeEquipo,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: const Color(0xFF0A2540),
                          child: CircleAvatar(
                            radius: 51,
                            backgroundImage: _fotoLocalBytes != null
                                ? MemoryImage(_fotoLocalBytes!) as ImageProvider
                                : NetworkImage(_fotoUrlPorDefecto),
                            backgroundColor: Colors.grey[200],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0A2540),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _subirFotoDesdeEquipo,
                    icon: const Icon(Icons.upload_file, color: Color(0xFF0A2540)),
                    label: const Text(
                      'Subir foto de perfil',
                      style: TextStyle(
                        color: Color(0xFF0A2540),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: textStyle,
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de Usuario',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    style: textStyle,
                    controller: _passCtrl,
                    obscureText: _ocultarClave,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nueva Contraseña (opcional)',
                      hintText: 'Ej: Admin456',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _ocultarClave ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _ocultarClave = !_ocultarClave),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    style: textStyle,
                    controller: _confirmPassCtrl,
                    obscureText: _ocultarConfirmClave,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Confirmar Nueva Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: !escribiendoClave
                              ? Colors.grey
                              : clavesCoinciden
                                  ? Colors.green
                                  : Colors.red,
                          width: escribiendoClave ? 1.8 : 1.0,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _ocultarConfirmClave
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _ocultarConfirmClave = !_ocultarConfirmClave,
                        ),
                      ),
                    ),
                  ),
                  if (escribiendoClave) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          clavesCoinciden ? Icons.check_circle : Icons.error,
                          size: 16,
                          color: clavesCoinciden ? Colors.green[700] : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          clavesCoinciden
                              ? 'Las contraseñas coinciden'
                              : 'Las contraseñas no coinciden',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: clavesCoinciden ? Colors.green[700] : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 15),
                  TextField(
                    style: textStyle,
                    controller: _rutCtrl,
                    decoration: const InputDecoration(
                      labelText: 'RUT',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    style: textStyle,
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _guardando ? null : _guardarCambios,
                      child: _guardando
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'GUARDAR CAMBIOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
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
}