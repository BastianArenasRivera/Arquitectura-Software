import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dashboard_view.dart';
import 'tablet_view.dart';

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

  Future<void> _ingresar() async {
    String u = _userCtrl.text.trim();
    String p = _passCtrl.text;

    if (u.isEmpty || p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Completa todos los campos"), backgroundColor: Colors.red));
      return;
    }

    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$').hasMatch(p)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La clave debe tener 1 mayúscula, 1 minúscula y 1 número."), backgroundColor: Colors.red));
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"usuario": u, "password": p}),
      );

      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        if (data['rol'] == 'Administrador' && widget.rolDestino == 'Administrador') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardAdminView()));
        } else if (data['rol'] == 'Tablet' && widget.rolDestino == 'Tablet') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TabletGruaView(nombre: data['nombre'])));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuario no autorizado para esta vista"), backgroundColor: Colors.red));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Credenciales incorrectas"), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error de servidor: Verifica que FastAPI esté encendido"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.rolDestino == 'Administrador';
    
    // Paleta dinámica según el rol
    Color bgColor = isAdmin ? const Color(0xFF0A2540) : Colors.black; // Azul para Admin, Negro para Tablet
    Color appBarColor = isAdmin ? const Color(0xFF061A2E) : Colors.grey[900]!;
    Color accentColor = isAdmin ? Colors.white : Colors.orange;
    Color btnBgColor = isAdmin ? Colors.blue[700]! : Colors.orange;
    Color btnTextColor = isAdmin ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('LOGIN - ${widget.rolDestino}', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)), 
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: accentColor),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isAdmin ? Icons.admin_panel_settings : Icons.security, size: 80, color: accentColor),
              const SizedBox(height: 30),
              TextField(
                controller: _userCtrl, 
                style: TextStyle(color: accentColor), 
                decoration: InputDecoration(
                  labelText: 'Usuario', 
                  labelStyle: TextStyle(color: accentColor),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: accentColor)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentColor, width: 2))
                )
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passCtrl, 
                obscureText: _ocultarClave, 
                style: TextStyle(color: accentColor), 
                decoration: InputDecoration(
                  labelText: 'Contraseña', 
                  labelStyle: TextStyle(color: accentColor),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: accentColor)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentColor, width: 2)),
                  suffixIcon: IconButton(
                    icon: Icon(_ocultarClave ? Icons.visibility : Icons.visibility_off, color: accentColor),
                    onPressed: () {
                      setState(() {
                        _ocultarClave = !_ocultarClave;
                      });
                    },
                  )
                )
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, height: 50, 
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: btnBgColor, foregroundColor: btnTextColor), 
                  onPressed: _ingresar, 
                  child: const Text('AUTENTICAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}