import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; 
import '../models.dart';
import 'register_screen.dart'; // <--- DODAJ IMPORT

class LoginScreen extends StatefulWidget {
  final void Function(AppUser user) onLogin;

  const LoginScreen({
    super.key,
    required this.onLogin,
  });

  @override
  State<LoginScreen> createState() {
    return _LoginScreenState();
  }
}

class _LoginScreenState extends State<LoginScreen> {

  final TextEditingController _emailController = TextEditingController(
    text: 'admin@pogodynka.pl', 
  );
  final TextEditingController _passwordController = TextEditingController(
    text: 'admin123',
  );

  bool _isLoading = false;
  String? _errorText;
  final String _baseUrl = 'http://localhost:8080';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    try {
      final url = Uri.parse('$_baseUrl/login');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final userData = data['user'];
      
          final user = AppUser(
            id: userData['id'], 
            email: userData['email'],
            role: (userData['roleId'] == 1) ? UserRole.admin : UserRole.user,
          );

          widget.onLogin(user); 
        
        } else {
          setState(() {
            _errorText = data['message'] ?? 'Błąd logowania';
          });
        }
      } else {
        setState(() {
          _errorText = 'Błąd serwera: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorText = 'Błąd połączenia. Czy serwer działa? ($e)';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_circle, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'POGODYNKA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF111827),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email, color: Colors.white60),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Hasło',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF111827),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white60),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Zaloguj się',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              // --- GUZIK REJESTRACJI ---
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const RegisterScreen()));
                },
                child: const Text("Nie masz konta? Zarejestruj się", style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}