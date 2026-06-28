class MissionMockModel {
  final String id;
  final String droneId;
  final String routeName;
  final double currentProgress; // 0.0 to 1.0
  final String destination;
  final String payload;

  const MissionMockModel({
    required this.id,
    required this.droneId,
    required this.routeName,
    required this.currentProgress,
    required this.destination,
    required this.payload,
  });
}

final List<MissionMockModel> mockMissions = [
  const MissionMockModel(id: 'MIS-001', droneId: 'DRN-001', routeName: 'Corridor Alpha-1', currentProgress: 0.45, destination: 'Engineering Hub', payload: 'Microscope Slides'),
  const MissionMockModel(id: 'MIS-002', droneId: 'DRN-002', routeName: 'Corridor Beta-3', currentProgress: 0.85, destination: 'Library Lobby', payload: 'Document Envelopes'),
  ...List.generate(18, (index) {
    final id = index + 3;
    return MissionMockModel(
      id: 'MIS-0$id',
      droneId: 'DRN-0${index % 4 + 5}',
      routeName: 'Corridor Custom-$id',
      currentProgress: (index % 5) * 0.2,
      destination: 'Campus Pad $id',
      payload: 'Academic Package #$id',
    );
  })
];
