import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models.dart';

class HistoryScreen extends StatefulWidget {
  final Station station;
  const HistoryScreen({super.key, required this.station});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _history = [];
  Map<String, dynamic> _progiMap = {};
  bool _isLoading = true;
  final String _baseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/measurements/${widget.station.id}')),
        http.get(Uri.parse('$_baseUrl/progi')),
      ]);

      if (results[0].statusCode == 200 && results[1].statusCode == 200) {
        final List progiList = jsonDecode(results[1].body);
        setState(() {
          _history = jsonDecode(results[0].body);
          _progiMap = { for (var item in progiList) item['kod_parametru'] : item };
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Widget _miniStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Historia Pomiarów', style: TextStyle(fontSize: 16)),
            Text(widget.station.name, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
        backgroundColor: const Color(0xFF050816),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                final double temp = double.tryParse(item['temp']?.toString() ?? '0') ?? 0.0;
                final double wind = double.tryParse(item['wind']?.toString() ?? '0') ?? 0.0;
                final String humStr = item['hum']?.toString() ?? '-';
                final String pressStr = item['press']?.toString() ?? '-';
                final String timeStr = item['czas'].toString();

                // --- LOGIKA PROGÓW ---
                final tProg = _progiMap['temperatura'];
                final wProg = _progiMap['wiatr'];

                bool isUpal = tProg != null && temp > (tProg['wartosc_max'] ?? 999);
                bool isMroz = tProg != null && temp < (tProg['wartosc_min'] ?? -999);
                bool isWichura = wProg != null && wind > (wProg['wartosc_max'] ?? 999);
                
                bool isAlert = isUpal || isMroz || isWichura;
                String alertText = isUpal ? "UPAŁ" : (isMroz ? "MRÓZ" : (isWichura ? "WICHURA" : ""));

                // --- KOLORYSTYKA ---
                // 1. Kolor Alertu (Ramka, Ikona, Napis Alertu) -> ZAWSZE CZERWONY
                const Color alertUiColor = Colors.redAccent;

                // 2. Kolor Temperatury (Napis "TEMPERATURA", stopnie, pasek)
                Color tempColor = Colors.orangeAccent; // Default
                if (isUpal) tempColor = Colors.redAccent;
                if (isMroz) tempColor = Colors.cyanAccent;

                final double barWidth = (temp.abs() / 40.0).clamp(0.01, 1.0);
                final parts = timeStr.split(' ');
                final datePart = parts[0];
                final timePart = parts.length > 1 ? parts[1] : "";

                return Card(
                  color: const Color(0xFF1B2640),
                  margin: const EdgeInsets.only(bottom: 12),
                  // Ramka alertu ZAWSZE czerwona
                  shape: isAlert 
                    ? RoundedRectangleBorder(
                        side: const BorderSide(color: alertUiColor, width: 2), 
                        borderRadius: BorderRadius.circular(12)
                      )
                    : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 75,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(timePart, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(datePart, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              if (isAlert) ...[
                                const SizedBox(height: 10),
                                const Icon(Icons.warning_amber_rounded, color: alertUiColor, size: 28),
                                Text(alertText, style: const TextStyle(color: alertUiColor, fontSize: 10, fontWeight: FontWeight.bold))
                              ]
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("TEMPERATURA", style: TextStyle(color: tempColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                  Text('${temp.toStringAsFixed(1)} °C', style: TextStyle(color: tempColor, fontWeight: FontWeight.bold, fontSize: 22)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 8,
                                width: double.infinity,
                                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: barWidth,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: tempColor, 
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [BoxShadow(color: tempColor.withOpacity(0.5), blurRadius: 6)]
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _miniStat(Icons.air, "${wind.toStringAsFixed(1)} m/s", isWichura ? Colors.redAccent : Colors.blueGrey),
                                  _miniStat(Icons.water_drop, "$humStr %", Colors.lightBlue),
                                  _miniStat(Icons.speed, "$pressStr hPa", Colors.green),
                                ],
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}