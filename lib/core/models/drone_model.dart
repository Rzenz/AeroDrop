enum DroneStatus { available, busy, maintenance, offline }

class DroneModel {
  final String id;
  final String name;
  final double batteryLevel; // 0.0 to 100.0
  final DroneStatus status;
  final double maxPayload; // in kg
  final String modelType; // e.g. AeroCarrier-X, SkyLifter-V2
  final String currentCoordinates;

  DroneModel({
    required this.id,
    required this.name,
    required this.batteryLevel,
    required this.status,
    required this.maxPayload,
    required this.modelType,
    required this.currentCoordinates,
  });

  DroneModel copyWith({
    String? id,
    String? name,
    double? batteryLevel,
    DroneStatus? status,
    double? maxPayload,
    String? modelType,
    String? currentCoordinates,
  }) {
    return DroneModel(
      id: id ?? this.id,
      name: name ?? this.name,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      status: status ?? this.status,
      maxPayload: maxPayload ?? this.maxPayload,
      modelType: modelType ?? this.modelType,
      currentCoordinates: currentCoordinates ?? this.currentCoordinates,
    );
  }
}
