import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mock_data/weather_mock.dart';

class WeatherMockNotifier extends StateNotifier<WeatherMockData> {
  WeatherMockNotifier() : super(WeatherMockData.safe);

  void setScenario(WeatherScenario scenario) {
    switch (scenario) {
      case WeatherScenario.safe:
        state = WeatherMockData.safe;
        break;
      case WeatherScenario.moderate:
        state = WeatherMockData.moderate;
        break;
      case WeatherScenario.dangerous:
        state = WeatherMockData.dangerous;
        break;
    }
  }
}

final weatherMockProvider = StateNotifierProvider<WeatherMockNotifier, WeatherMockData>((ref) {
  return WeatherMockNotifier();
});
