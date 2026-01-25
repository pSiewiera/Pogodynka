import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models.dart';
import 'history_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  final AppUser currentUser;

  const DashboardScreen({super.key, required this.currentUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Station> _stations = [];
  bool _isLoading = true;
  final String _baseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _fetchStations();
  }

  Future<void> _fetchStations() async {
    try {
      final int roleId = widget.currentUser.role == UserRole.admin ? 1 : 2;
      final url = Uri.parse('$_baseUrl/stations?userId=${widget.currentUser.id}&roleId=$roleId');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _stations = data.map((json) => Station.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Błąd: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStation(String id) async {
    final roleId = widget.currentUser.role == UserRole.admin ? 1 : 2;
    try {
 
      await http.delete(Uri.parse('$_baseUrl/stations/$id?userId=${widget.currentUser.id}&roleId=$roleId'));
      _fetchStations();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usunięto stację')));
    } catch (e) {
      print(e);
    }
  }

  Future<void> _toggleVisibility(String id) async {
    try {
      await http.patch(Uri.parse('$_baseUrl/stations/$id/toggle'));
      _fetchStations();
    } catch (e) {
      print(e);
    }
  }

  Future<void> _addStation(String name, String desc, StationType type, bool isPublic, bool withData) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/stations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'description': desc,
          'type': type == StationType.mobile ? 'ruchoma' : 'stacjonarna',
          'userId': widget.currentUser.id,
          'isPublic': isPublic,
          'withData': withData,
        }),
      );
      _fetchStations();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('Błąd dodawania: $e');
    }
  }

 
  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    StationType selectedType = StationType.staticStation;
    bool isPublic = true;
    bool withData = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF111827),
            title: const Text('Nowa stacja', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nazwa', labelStyle: TextStyle(color: Colors.white70))),
                  TextField(controller: descCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Opis', labelStyle: TextStyle(color: Colors.white70))),
                  const SizedBox(height: 16),
                  
                  DropdownButton<StationType>(
                    value: selectedType,
                    dropdownColor: const Color(0xFF1B2640),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: StationType.staticStation, child: Text('Stacjonarna ')),
                      DropdownMenuItem(value: StationType.mobile, child: Text('Ruchoma ')),
                    ],
                    onChanged: (val) => setDialogState(() => selectedType = val!),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Publiczna', style: TextStyle(color: Colors.white)),
                    value: isPublic,
                    activeColor: Colors.green,
                    onChanged: (val) => setDialogState(() => isPublic = val),
                  ),


                  CheckboxListTile(
                    title: const Text('Symuluj dane (Demo)', style: TextStyle(color: Colors.blueAccent)),
                    value: withData,
                    activeColor: Colors.blue,
                    onChanged: (val) => setDialogState(() => withData = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
              ElevatedButton(
                onPressed: () => _addStation(nameCtrl.text, descCtrl.text, selectedType, isPublic, withData),
                child: const Text('Dodaj'),
              ),
            ],
          );
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _stations.length,
              itemBuilder: (context, index) {
                final station = _stations[index];
                final bool canEdit = (station.ownerId == widget.currentUser.id) || 
                                     (widget.currentUser.role == UserRole.admin);

                return Card(
                  color: const Color(0xFF1B2640),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(

                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (ctx) => HistoryScreen(station: station))
                      );
                    },
                    leading: Icon(
                      station.type == StationType.mobile ? Icons.directions_boat : Icons.home,
                      color: station.ownerId == widget.currentUser.id ? Colors.yellow : Colors.blueAccent,
                    ),
                    title: Text(station.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      station.description ?? '', 
                      style: TextStyle(color: Colors.white60)
                    ),
                    trailing: canEdit ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(station.isPublic ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                          onPressed: () => _toggleVisibility(station.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deleteStation(station.id),
                        ),
                      ],
                    ) : null,
                  ),
                );
              },
            ),
    );
  }
}