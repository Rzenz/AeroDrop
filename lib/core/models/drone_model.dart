enum DroneStatus { available, assigned, busy, charging, maintenance, offline, returning }

class DroneModel {
  final String id;
  final String dbId;
  final String name;
  final double batteryLevel; // 0.0 to 100.0
  final DroneStatus status;
  final double maxPayload; // in kg
  final String modelType;
  final String currentCoordinates;

  DroneModel({
    required this.id,
    this.dbId = '80000000-0000-0000-0000-000000000001',
    required this.name,
    required this.batteryLevel,
    required this.status,
    required this.maxPayload,
    required this.modelType,
    required this.currentCoordinates,
  });

  DroneModel copyWith({
    String? id,
    String? dbId,
    String? name,
    double? batteryLevel,
    DroneStatus? status,
    double? maxPayload,
    String? modelType,
    String? currentCoordinates,
  }) {
    return DroneModel(
      id: id ?? this.id,
      dbId: dbId ?? this.dbId,
      name: name ?? this.name,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      status: status ?? this.status,
      maxPayload: maxPayload ?? this.maxPayload,
      modelType: modelType ?? this.modelType,
      currentCoordinates: currentCoordinates ?? this.currentCoordinates,
    );
  }
}
