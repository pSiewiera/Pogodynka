import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models.dart';

class AlertsScreen extends StatefulWidget {
  final AppUser currentUser;
  const AlertsScreen({super.key, required this.currentUser});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> _progi = [];
  bool _isLoading = true;
  final String _baseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _pobierzProgi();
  }

  Future<void> _pobierzProgi() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/progi'));
      if (res.statusCode == 200) {
        setState(() {
          _progi = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Błąd pobierania progów: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _zapiszProg(String kod, String? min, String max) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/progi'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'kod_parametru': kod,
          'wartosc_min': (min == null || min.isEmpty) ? null : double.tryParse(min),
          'wartosc_max': double.tryParse(max) ?? 0.0,
        }),
      );
      if (res.statusCode == 200) {
        _pobierzProgi();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pomyślnie zaktualizowano próg")),
        );
      }
    } catch (e) {
      debugPrint("Błąd zapisu: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.currentUser.role == UserRole.admin;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  "Konfiguracja Alertów",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  isAdmin 
                    ? "Administartor-Możesz modyfikować progi."
                    : "",
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 24),
                ..._progi.where((p) => p['kod_parametru'] != 'cisnienie').map((p) {
                  return _buildProgCard(p, isAdmin);
                }).toList(),
              ],
            ),
    );
  }

  Widget _buildProgCard(dynamic prog, bool isAdmin) {
    String kod = prog['kod_parametru'];
    String nazwa = prog['nazwa_wyswietlana'] ?? kod;
  
    final minCtrl = TextEditingController(text: prog['wartosc_min']?.toString() ?? "");
    final maxCtrl = TextEditingController(text: prog['wartosc_max']?.toString() ?? "");

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2640),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                kod == 'wiatr' ? Icons.air : Icons.thermostat,
                color: Colors.amber,
              ),
              const SizedBox(width: 10),
              Text(
                nazwa,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Dla wiatru ukrywamy pole MIN
              if (kod != 'wiatr') ...[
                Expanded(child: _buildField("Wartość Min", minCtrl, isAdmin)),
                const SizedBox(width: 15),
              ],
              Expanded(child: _buildField(kod == 'wiatr' ? "Maks. prędkość" : "Wartość Max", maxCtrl, isAdmin)),
              
              if (isAdmin) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => _zapiszProg(kod, kod == 'wiatr' ? null : minCtrl.text, maxCtrl.text),
                  icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 32),
                ),
              ],
            ],
          ),
          if (kod == 'wiatr')
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text("Górny próg dla alertu", 
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool enabled) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}