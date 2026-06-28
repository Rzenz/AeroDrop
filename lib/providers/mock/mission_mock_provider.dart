import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mock_data/missions_mock.dart';

class MissionMockState {
  final List<MissionMockModel> missions;
  final Map<String, String> autopilotStates; // MissionId -> Status text

  MissionMockState({
    required this.missions,
    required this.autopilotStates,
  });

  MissionMockState copyWith({
    List<MissionMockModel>? missions,
    Map<String, String>? autopilotStates,
  }) {
    return MissionMockState(
      missions: missions ?? this.missions,
      autopilotStates: autopilotStates ?? this.autopilotStates,
    );
  }
}

class MissionMockNotifier extends StateNotifier<MissionMockState> {
  MissionMockNotifier()
      : super(MissionMockState(
          missions: List.from(mockMissions),
          autopilotStates: {},
        ));

  void updateAutopilotState(String missionId, String stateText) {
    final updatedStates = Map<String, String>.from(state.autopilotStates);
    updatedStates[missionId] = stateText;
    state = state.copyWith(autopilotStates: updatedStates);
  }

  void updateProgress(String missionId, double progress) {
    state = state.copyWith(
      missions: state.missions.map((m) {
        if (m.id == missionId) {
          return MissionMockModel(
            id: m.id,
            droneId: m.droneId,
            routeName: m.routeName,
            currentProgress: progress,
            destination: m.destination,
            payload: m.payload,
          );
        }
        return m;
      }).toList(),
    );
  }

  void reset() {
    state = MissionMockState(
      missions: List.from(mockMissions),
      autopilotStates: {},
    );
  }
}

final missionMockProvider = StateNotifierProvider<MissionMockNotifier, MissionMockState>((ref) {
  return MissionMockNotifier();
});
