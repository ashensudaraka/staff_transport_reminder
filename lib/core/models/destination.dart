import 'dart:convert';

enum DestinationType { home, work }

extension DestinationTypeExtension on DestinationType {
  String get displayName => this == DestinationType.home ? 'Home' : 'Work';
  String get key => this == DestinationType.home ? 'home' : 'work';
}

class Destination {
  final DestinationType type;
  final double? latitude;
  final double? longitude;
  final double alertDistanceMeters;

  const Destination({
    required this.type,
    this.latitude,
    this.longitude,
    this.alertDistanceMeters = 700.0,
  });

  bool get isSaved => latitude != null && longitude != null;

  String get displayName => type.displayName;

  String get alertDistanceLabel {
    if (alertDistanceMeters >= 1000) {
      final km = alertDistanceMeters / 1000;
      return km == km.roundToDouble() ? '${km.toInt()} km' : '${km.toStringAsFixed(1)} km';
    }
    return '${alertDistanceMeters.toInt()} m';
  }

  Destination copyWith({
    DestinationType? type,
    double? latitude,
    double? longitude,
    double? alertDistanceMeters,
  }) {
    return Destination(
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      alertDistanceMeters: alertDistanceMeters ?? this.alertDistanceMeters,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.key,
        'latitude': latitude,
        'longitude': longitude,
        'alertDistanceMeters': alertDistanceMeters,
      };

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      type: json['type'] == 'work' ? DestinationType.work : DestinationType.home,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      alertDistanceMeters: (json['alertDistanceMeters'] as num?)?.toDouble() ?? 700.0,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Destination.fromJsonString(String str) =>
      Destination.fromJson(jsonDecode(str) as Map<String, dynamic>);

  @override
  String toString() =>
      'Destination(type: ${type.key}, lat: $latitude, lng: $longitude, dist: ${alertDistanceMeters}m)';
}
