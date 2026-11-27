import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'dashboard_view.dart';
import 'tablet_view.dart';

class LoginView extends StatefulWidget {
  final String rolDestino;
  const LoginView({super.key, required this.rolDestino});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _ocultarClave = true;
  bool _cargando = false;
  String? _errorMensaje;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final usuario = _userCtrl.text.trim();
    final password = _passCtrl.text;

    if (usuario.isEmpty || password.isEmpty) {
      setState(() {
        _errorMensaje = 'Debes ingresar usuario y contraseña.';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'usuario': usuario,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (!mounted) return;
        if (widget.rolDestino == 'Administrador') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardAdminView()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TabletGruaView(
                nombreOperador: data['nombre'] ?? usuario,
                username: data['username'] ?? usuario,
              ),
            ),
          );
        }
      } else if (res.statusCode == 403) {
        final data = jsonDecode(res.body);
        setState(() {
          _errorMensaje = data['detail'] ??
              'Licencia de terminal cancelada por reporte de robo.';
        });
      } else {
        setState(() {
          _errorMensaje = 'Usuario o contraseña incorrectos.';
        });
      }
    } catch (_) {
      setState(() {
        _errorMensaje = 'No se pudo conectar con FastAPI. Verifica el servidor.';
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esAdmin = widget.rolDestino == 'Administrador';
    final Color acento =
        esAdmin ? const Color(0xFF0284C7) : const Color(0xFFF59E0B);

    return Scaffold(
      backgroundColor: const Color(0xFF06111E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A192F),
        elevation: 0,
        title: Text(
          'Acceso ${widget.rolDestino}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1578575437130-527eed3abbec?auto=format&fit=crop&w=1920&q=80',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          Container(
            color: const Color(0xEB06111E),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151F32).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: acento.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        esAdmin ? Icons.admin_panel_settings : Icons.engineering,
                        color: acento,
                        size: 50,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        esAdmin ? 'PANEL CENTRAL TOS' : 'CABINA GRÚA RTG-04',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Autenticación requerida para ${widget.rolDestino}',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(height: 26),
                      TextField(
                        controller: _userCtrl,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Usuario',
                          hintText: 'Ingresa tu usuario',
                          hintStyle: const TextStyle(color: Colors.white30),
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.person, color: acento),
                          filled: true,
                          fillColor: const Color(0xFF0B1120),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _ocultarClave,
                        autocorrect: false,
                        enableSuggestions: false,
                        onSubmitted: (_) => _iniciarSesion(),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          hintText: 'Ingresa tu contraseña',
                          hintStyle: const TextStyle(color: Colors.white30),
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.lock, color: acento),
                          filled: true,
                          fillColor: const Color(0xFF0B1120),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _ocultarClave
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white60,
                            ),
                            onPressed: () =>
                                setState(() => _ocultarClave = !_ocultarClave),
                          ),
                        ),
                      ),
                      if (_errorMensaje != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.gpp_bad,
                                  color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMensaje!,
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: acento,
                            foregroundColor: esAdmin
                                ? Colors.white
                                : const Color(0xFF0B1120),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _cargando ? null : _iniciarSesion,
                          child: _cargando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'INGRESAR AL SISTEMA',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 0.8,
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
        ],
      ),
    );
  }
}