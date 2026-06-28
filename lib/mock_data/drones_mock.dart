import '../core/models/drone_model.dart';

final List<DroneModel> mockDrones = [
  DroneModel(id: 'DRN-001', name: 'AeroCarrier Falcon', batteryLevel: 92.5, status: DroneStatus.available, maxPayload: 5.0, modelType: 'AeroCarrier-X', currentCoordinates: '10.3276° N, 123.9507° E'),
  DroneModel(id: 'DRN-002', name: 'SkyLifter Titan', batteryLevel: 45.0, status: DroneStatus.busy, maxPayload: 15.0, modelType: 'SkyLifter-V2', currentCoordinates: '10.3286° N, 123.9512° E'),
  DroneModel(id: 'DRN-003', name: 'AeroCarrier Hawk', batteryLevel: 15.0, status: DroneStatus.maintenance, maxPayload: 5.0, modelType: 'AeroCarrier-X', currentCoordinates: '10.3280° N, 123.9498° E'),
  DroneModel(id: 'DRN-004', name: 'Shadow Swift', batteryLevel: 0.0, status: DroneStatus.offline, maxPayload: 2.5, modelType: 'Swift-Lite', currentCoordinates: '10.3272° N, 123.9518° E'),
  DroneModel(id: 'DRN-005', name: 'AeroCarrier Eagle', batteryLevel: 98.0, status: DroneStatus.available, maxPayload: 5.0, modelType: 'AeroCarrier-X', currentCoordinates: '10.3276° N, 123.9507° E'),
  DroneModel(id: 'DRN-006', name: 'SkyLifter Atlas', batteryLevel: 85.0, status: DroneStatus.available, maxPayload: 15.0, modelType: 'SkyLifter-V2', currentCoordinates: '10.3276° N, 123.9507° E'),
  DroneModel(id: 'DRN-007', name: 'Swift Phantom', batteryLevel: 62.0, status: DroneStatus.available, maxPayload: 2.5, modelType: 'Swift-Lite', currentCoordinates: '10.3276° N, 123.9507° E'),
  DroneModel(id: 'DRN-008', name: 'Goliath Carrier', batteryLevel: 75.0, status: DroneStatus.available, maxPayload: 20.0, modelType: 'SkyLifter-Mega', currentCoordinates: '10.3276° N, 123.9507° E'),
  DroneModel(id: 'DRN-009', name: 'AeroCarrier Kestrel', batteryLevel: 88.0, status: DroneStatus.available, maxPayload: 5.0, modelType: 'AeroCarrier-X', currentCoordinates: '10.3276° N, 123.9507° E'),
  DroneModel(id: 'DRN-010', name: 'Nova Express', batteryLevel: 90.0, status: DroneStatus.available, maxPayload: 3.0, modelType: 'Swift-Lite', currentCoordinates: '10.3276° N, 123.9507° E'),
];
