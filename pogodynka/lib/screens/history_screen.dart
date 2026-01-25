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
  bool _isLoading = true;
  final String _baseUrl = 'http://localhost:8080'; // Ustaw 10.0.2.2 dla Androida

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final url = Uri.parse('$_baseUrl/measurements/${widget.station.id}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _history = data;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print(e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Mały widget pomocniczy do wyświetlania ikony i wartości (wiatr, wilgoć, ciśnienie)
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
        titleTextStyle: const TextStyle(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.history_toggle_off, size: 60, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('Brak historii dla tej stacji.', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    
                    // --- BEZPIECZNE PARSOWANIE DANYCH ---
                    final String timeStr = item['czas'].toString();
                    
                    // Używamy tryParse, żeby uniknąć crasha jak przyjdzie null
                    final double temp = double.tryParse(item['temp']?.toString() ?? '0') ?? 0.0;
                    final double wind = double.tryParse(item['wind']?.toString() ?? '0') ?? 0.0;
                    
                    final String humStr = item['hum']?.toString() ?? '-';
                    final String pressStr = item['press']?.toString() ?? '-';

                    // --- LOGIKA PASKA TEMPERATURY ---
                    // Maksymalna skala paska to 40 stopni (możesz zwiększyć)
                    // clamp(0.01, 1.0) zapewnia, że pasek zawsze ma min. 1% szerokości (nawet dla 0.0 stopni)
                    final double barWidth = (temp.abs() / 40.0).clamp(0.01, 1.0);
                    
                    // Kolor paska: Niebieski dla ujemnych, Pomarańczowy dla dodatnich, Szary dla idealnego 0
                    Color barColor;
                    if (temp < 0) {
                      barColor = Colors.cyanAccent;
                    } else if (temp > 0) {
                      barColor = temp > 25 ? Colors.redAccent : Colors.orangeAccent;
                    } else {
                      barColor = Colors.white24; // Dla 0.0 stopni
                    }

                    // --- ALERT ---
                    // Warunek: Temp > 25 LUB Wiatr > 20 LUB Temp < -5 (Mróz)
                    bool isAlert = (temp > 25.0 || wind > 20.0 || temp < -5.0);
                    String alertText = "";
                    if (temp > 25) alertText = "UPAŁ";
                    else if (temp < -5) alertText = "MRÓZ";
                    else if (wind > 20) alertText = "WICHURA";

                    // Formatowanie daty/godziny (rozdzielamy spacją)
                    final parts = timeStr.split(' ');
                    final datePart = parts.length > 0 ? parts[0] : "";
                    final timePart = parts.length > 1 ? parts[1] : "";

                    return Card(
                      color: const Color(0xFF1B2640),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: isAlert 
                        ? RoundedRectangleBorder(
                            side: BorderSide(color: Colors.orange.withOpacity(0.6), width: 1.5), 
                            borderRadius: BorderRadius.circular(12)
                          )
                        : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // 1. LEWA STRONA (GODZINA + ALERT)
                            SizedBox(
                              width: 70, // Stała szerokość dla wyrównania
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    timePart,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    datePart,
                                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                                  ),
                                  if (isAlert) ...[
                                    const SizedBox(height: 8),
                                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                                    Text(alertText, style: const TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold))
                                  ]
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // 2. PRAWA STRONA (DANE + PASEK)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nagłówek i Wartość Temperatury
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        temp < 0 ? "NISKA TEMP." : "TEMPERATURA", 
                                        style: TextStyle(color: temp < 0 ? Colors.cyan : Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)
                                      ),
                                      Text(
                                        '${temp.toStringAsFixed(1)} °C',
                                        style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 20),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // --- PASEK WIZUALNY ---
                                  Stack(
                                    children: [
                                      // Tło paska (szare)
                                      Container(
                                        height: 8,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      // Właściwy pasek (kolorowy)
                                      FractionallySizedBox(
                                        widthFactor: barWidth,
                                        child: Container(
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: barColor,
                                            borderRadius: BorderRadius.circular(4),
                                            boxShadow: [
                                              BoxShadow(color: barColor.withOpacity(0.5), blurRadius: 4, spreadRadius: 0)
                                            ]
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  // --- POZOSTAŁE DANE ---
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _miniStat(Icons.air, "${wind.toStringAsFixed(1)} m/s", Colors.blueGrey),
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