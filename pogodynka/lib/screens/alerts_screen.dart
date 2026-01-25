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

  @override
  void initState() {
    super.initState();
    _pobierzProgi();
  }

  Future<void> _pobierzProgi() async {
    final res = await http.get(Uri.parse('http://localhost:8080/progi'));
    if (res.statusCode == 200) {
      setState(() {
        _progi = jsonDecode(res.body);
        _isLoading = false;
      });
    }
  }

  Future<void> _zapiszProg(String kod, String min, String max) async {
    await http.post(
      Uri.parse('http://localhost:8080/progi'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'kod_parametru': kod,
        'wartosc_min': double.tryParse(min) ?? 0,
        'wartosc_max': double.tryParse(max) ?? 0,
      }),
    );
    _pobierzProgi();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Zapisano zmiany")));
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
              const Text("Ustawienia Progów Alertów", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text(isAdmin ? "Jesteś administratorem - możesz edytować wartości." : "Podgląd aktualnych progów bezpieczeństwa.", 
                style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 20),
              ..._progi.map((p) => _buildProgCard(p, isAdmin)).toList(),
            ],
          ),
    );
  }

  Widget _buildProgCard(dynamic prog, bool isAdmin) {
    final minCtrl = TextEditingController(text: prog['wartosc_min'].toString());
    final maxCtrl = TextEditingController(text: prog['wartosc_max'].toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1B2640), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prog['nazwa_wyswietlana'], style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInput("Min", minCtrl, isAdmin)),
              const SizedBox(width: 16),
              Expanded(child: _buildInput("Max", maxCtrl, isAdmin)),
              if (isAdmin) IconButton(
                icon: const Icon(Icons.save, color: Colors.greenAccent),
                onPressed: () => _zapiszProg(prog['kod_parametru'], minCtrl.text, maxCtrl.text),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, bool enabled) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
      ),
    );
  }
}