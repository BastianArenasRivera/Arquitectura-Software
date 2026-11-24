import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dashboard_view.dart';
import 'tablet_view.dart';
import '../config/api_config.dart';

class LoginView extends StatefulWidget {
  final String rolDestino;
  const LoginView({super.key, required this.rolDestino});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _ocultarClave = true;
  bool _cargando = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (_cargando) return;

    String u = _userCtrl.text.trim();
    String p = _passCtrl.text;

    if (u.isEmpty || p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Completa todos los campos"), backgroundColor: Colors.red),
      );
      return;
    }

    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$').hasMatch(p)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La clave debe tener 1 mayúscula, 1 minúscula y 1 número."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"usuario": u, "password": p}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        if (data['rol'] == 'Administrador' && widget.rolDestino == 'Administrador') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardAdminView()));
        } else if (data['rol'] == 'Tablet' && widget.rolDestino == 'Tablet') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TabletGruaView(nombre: data['nombre'])));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Usuario no autorizado para esta vista"), backgroundColor: Colors.red),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Credenciales incorrectas"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error de servidor: Verifica que FastAPI esté encendido"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.rolDestino == 'Administrador';

    Color bgColor = isAdmin ? const Color(0xFF0A2540) : const Color(0xFF121212);
    Color cardColor = isAdmin ? const Color(0xFF103254) : const Color(0xFF1E1E1E);
    Color appBarColor = isAdmin ? const Color(0xFF061A2E) : Colors.black;
    Color accentColor = isAdmin ? Colors.white : Colors.orange;
    Color btnBgColor = isAdmin ? const Color(0xFF0EA5E9) : Colors.orange;
    Color btnTextColor = isAdmin ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'ACCESO AL SISTEMA - ${widget.rolDestino.toUpperCase()}',
          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: accentColor),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAdmin ? Icons.admin_panel_settings : Icons.precision_manufacturing,
                    size: 56,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isAdmin ? 'Panel Logístico Central' : 'Terminal de Operador',
                  style: TextStyle(color: accentColor, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ingresa tus credenciales institucionales',
                  style: TextStyle(color: accentColor.withValues(alpha: 0.75), fontSize: 13),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _userCtrl,
                  style: TextStyle(color: accentColor),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Usuario',
                    labelStyle: TextStyle(color: accentColor.withValues(alpha: 0.85)),
                    prefixIcon: Icon(Icons.person_outline, color: accentColor),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  obscureText: _ocultarClave,
                  style: TextStyle(color: accentColor),
                  onSubmitted: (_) => _ingresar(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: TextStyle(color: accentColor.withValues(alpha: 0.85)),
                    prefixIcon: Icon(Icons.lock_outline, color: accentColor),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_ocultarClave ? Icons.visibility : Icons.visibility_off, color: accentColor),
                      onPressed: () => setState(() => _ocultarClave = !_ocultarClave),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btnBgColor,
                      foregroundColor: btnTextColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _cargando ? null : _ingresar,
                    child: _cargando
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: btnTextColor),
                          )
                        : const Text('AUTENTICAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}