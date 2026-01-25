import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  Station? _selectedMobileStation;
  List<Station> _mobileStations = [];
  List<LatLng> _routePoints = [];
  bool _isLoadingStations = true;
  bool _isLoadingRoute = false;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchMobileStations();
  }

  Future<void> _fetchMobileStations() async {
    try {
      final response =
          await http.get(Uri.parse('http://localhost:8080/stations'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final stations =
            data.map((json) => Station.fromJson(json)).toList();

        setState(() {
          _mobileStations =
              stations.where((s) => s.type == StationType.mobile).toList();
          _isLoadingStations = false;

          if (_mobileStations.isNotEmpty) {
            _selectedMobileStation = _mobileStations.first;
            _fetchRoute(_selectedMobileStation!.id);
          }
        });
      }
    } catch (e) {
      print(e);
      setState(() => _isLoadingStations = false);
    }
  }

  Future<void> _fetchRoute(String stationId) async {
    setState(() => _isLoadingRoute = true);
    try {
      final response =
          await http.get(Uri.parse('http://localhost:8080/route/$stationId'));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        final List<LatLng> points = data.map((point) {
          return LatLng(
            (point['lat'] as num).toDouble(),
            (point['lon'] as num).toDouble(),
          );
        }).toList();

        setState(() {
          _routePoints = points;
          _isLoadingRoute = false;
        });

        if (points.isNotEmpty) {
          _mapController.move(points.last, 10.0);
        }
      }
    } catch (e) {
      print(e);
      setState(() => _isLoadingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: const Text('Mapa Tras'),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
        ),
        if (_mobileStations.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DropdownButtonFormField<Station>(
              value: _selectedMobileStation,
              dropdownColor: const Color(0xFF1B2640),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Wybierz stację ruchomą',
                filled: true,
                fillColor: const Color(0xFF1B2640),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _mobileStations
                  .map((s) =>
                      DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMobileStation = val);
                  _fetchRoute(val.id);
                }
              },
            ),
          ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 10)
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _isLoadingRoute
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: _mapController,
                    options: const MapOptions(
                      initialCenter: LatLng(52.0, 19.0),
                      initialZoom: 6.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.pogodynka.app',
                      ),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              strokeWidth: 4.0,
                              color: Colors.blueAccent,
                            ),
                          ],
                        ),
                      if (_routePoints.isNotEmpty)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _routePoints.first,
                              width: 80,
                              height: 80,
                              child: const Icon(Icons.flag,
                                  color: Colors.green, size: 40),
                            ),
                            Marker(
                              point: _routePoints.last,
                              width: 80,
                              height: 80,
                              child: const Icon(Icons.directions_boat,
                                  color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
