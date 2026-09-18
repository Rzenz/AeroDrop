class TelemetryModel {
  final String? id;
  final String deliveryId;
  final String? droneId;
  final String droneCode;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? batteryLevel;
  final double? signalStrength;
  final double? heading;
  final String? eventType;
  final double progress;
  final DateTime recordedAt;

  const TelemetryModel({
    this.id,
    required this.deliveryId,
    this.droneId,
    this.droneCode = 'DRN-001',
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.batteryLevel,
    this.signalStrength,
    this.heading,
    this.eventType,
    this.progress = 0.0,
    required this.recordedAt,
  });

  factory TelemetryModel.fromMap(Map<String, dynamic> map) {
    return TelemetryModel(
      id: map['id']?.toString(),
      deliveryId: map['delivery_id']?.toString() ?? '',
      droneId: map['drone_id']?.toString(),
      droneCode: map['drone_code']?.toString() ?? 'DRN-001',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 10.3156,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 123.9016,
      altitude: (map['altitude'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      batteryLevel: (map['battery_level'] as num?)?.toDouble(),
      signalStrength: (map['signal_strength'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      eventType: map['event_type']?.toString(),
      progress: ((map['progress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
      recordedAt: map['recorded_at'] != null
          ? DateTime.tryParse(map['recorded_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'delivery_id': deliveryId,
      if (droneId != null) 'drone_id': droneId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'battery_level': batteryLevel,
      'signal_strength': signalStrength,
      'heading': heading,
      'event_type': eventType,
      'progress': progress,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  TelemetryModel copyWith({
    String? id,
    String? deliveryId,
    String? droneId,
    String? droneCode,
    double? latitude,
    double? longitude,
    double? altitude,
    double? speed,
    double? batteryLevel,
    double? signalStrength,
    double? heading,
    String? eventType,
    double? progress,
    DateTime? recordedAt,
  }) {
    return TelemetryModel(
      id: id ?? this.id,
      deliveryId: deliveryId ?? this.deliveryId,
      droneId: droneId ?? this.droneId,
      droneCode: droneCode ?? this.droneCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      signalStrength: signalStrength ?? this.signalStrength,
      heading: heading ?? this.heading,
      eventType: eventType ?? this.eventType,
      progress: progress ?? this.progress,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}
