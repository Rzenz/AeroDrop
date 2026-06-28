class AnalyticsMockData {
  static const double successRate = 98.4;
  static const int totalDeliveries = 1420;
  static const double activeDroneUtilization = 78.5;

  static const List<double> dailyDeliveries = [12, 18, 15, 22, 28, 30, 25];
  static const List<double> weeklyDeliveries = [85, 92, 110, 95, 105, 120, 115, 130];
  static const List<double> monthlyDeliveries = [350, 410, 480, 520, 490, 550];

  static const Map<String, double> droneUtilization = {
    'DRN-001': 82.5,
    'DRN-002': 71.0,
    'DRN-003': 45.5,
    'DRN-004': 0.0,
    'DRN-005': 90.0,
  };
}
