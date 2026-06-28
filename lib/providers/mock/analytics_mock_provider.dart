import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mock_data/analytics_mock.dart';

class AnalyticsState {
  final double successRate;
  final int totalDeliveries;
  final double activeDroneUtilization;
  final List<double> dailyDeliveries;
  final List<double> weeklyDeliveries;
  final List<double> monthlyDeliveries;
  final Map<String, double> droneUtilization;

  AnalyticsState({
    required this.successRate,
    required this.totalDeliveries,
    required this.activeDroneUtilization,
    required this.dailyDeliveries,
    required this.weeklyDeliveries,
    required this.monthlyDeliveries,
    required this.droneUtilization,
  });

  AnalyticsState copyWith({
    double? successRate,
    int? totalDeliveries,
    double? activeDroneUtilization,
    List<double>? dailyDeliveries,
    List<double>? weeklyDeliveries,
    List<double>? monthlyDeliveries,
    Map<String, double>? droneUtilization,
  }) {
    return AnalyticsState(
      successRate: successRate ?? this.successRate,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      activeDroneUtilization: activeDroneUtilization ?? this.activeDroneUtilization,
      dailyDeliveries: dailyDeliveries ?? this.dailyDeliveries,
      weeklyDeliveries: weeklyDeliveries ?? this.weeklyDeliveries,
      monthlyDeliveries: monthlyDeliveries ?? this.monthlyDeliveries,
      droneUtilization: droneUtilization ?? this.droneUtilization,
    );
  }
}

class AnalyticsMockNotifier extends StateNotifier<AnalyticsState> {
  AnalyticsMockNotifier()
      : super(AnalyticsState(
          successRate: AnalyticsMockData.successRate,
          totalDeliveries: AnalyticsMockData.totalDeliveries,
          activeDroneUtilization: AnalyticsMockData.activeDroneUtilization,
          dailyDeliveries: AnalyticsMockData.dailyDeliveries,
          weeklyDeliveries: AnalyticsMockData.weeklyDeliveries,
          monthlyDeliveries: AnalyticsMockData.monthlyDeliveries,
          droneUtilization: AnalyticsMockData.droneUtilization,
        ));

  void incrementDeliveries() {
    state = state.copyWith(
      totalDeliveries: state.totalDeliveries + 1,
    );
  }

  void reset() {
    state = AnalyticsState(
      successRate: AnalyticsMockData.successRate,
      totalDeliveries: AnalyticsMockData.totalDeliveries,
      activeDroneUtilization: AnalyticsMockData.activeDroneUtilization,
      dailyDeliveries: AnalyticsMockData.dailyDeliveries,
      weeklyDeliveries: AnalyticsMockData.weeklyDeliveries,
      monthlyDeliveries: AnalyticsMockData.monthlyDeliveries,
      droneUtilization: AnalyticsMockData.droneUtilization,
    );
  }
}

final analyticsMockProvider = StateNotifierProvider<AnalyticsMockNotifier, AnalyticsState>((ref) {
  return AnalyticsMockNotifier();
});
