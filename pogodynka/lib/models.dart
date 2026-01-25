

enum StationType { staticStation, mobile }
enum UserRole { admin, user, guest }

class AppUser {
  final int id;
  final String email;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.email,
    required this.role,
  });
}
class Station {
  final String id;
  final String name;
  final String? description;
  final StationType type;
  final bool isPublic;
  final int ownerId;
  final bool maAlert; // <--- Polskie pole

  const Station({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    this.isPublic = true,
    required this.ownerId,
    this.maAlert = false,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'].toString(),
      name: json['name'],
      description: json['description'],
      type: json['type'] == 'mobile' ? StationType.mobile : StationType.staticStation,
      isPublic: json['isPublic'] ?? true,
      ownerId: json['ownerId'] ?? 0,
      maAlert: json['ma_alert'] ?? false, // Pobieramy z bazy
    );
  }
}

class WeatherMeasurement {
  final DateTime timestamp;
  final double value;
  final String type; 

  const WeatherMeasurement({
    required this.timestamp,
    required this.value,
    required this.type,
  });

  factory WeatherMeasurement.fromJson(Map<String, dynamic> json) {
    return WeatherMeasurement(
      timestamp: DateTime.parse(json['timestamp']),
      value: (json['value'] as num).toDouble(),
      type: json['type'] ?? 'nieznany',
    );
  }
}

class AlertUiModel {
  final String title;
  final String description;
  bool isEnabled;

  AlertUiModel({
    required this.title,
    required this.description,
    this.isEnabled = true,
  });
}