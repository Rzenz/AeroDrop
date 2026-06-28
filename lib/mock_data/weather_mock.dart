enum WeatherScenario { safe, moderate, dangerous }

class WeatherMockData {
  final WeatherScenario scenario;
  final String description;
  final double windSpeed; // in knots
  final double precipitation; // percentage
  final String statusText;

  const WeatherMockData({
    required this.scenario,
    required this.description,
    required this.windSpeed,
    required this.precipitation,
    required this.statusText,
  });

  static const WeatherMockData safe = WeatherMockData(
    scenario: WeatherScenario.safe,
    description: 'Clear Skies, Perfect Visibility',
    windSpeed: 4.8,
    precipitation: 5.0,
    statusText: 'All flight corridors clear. Autopilots allowed.',
  );

  static const WeatherMockData moderate = WeatherMockData(
    scenario: WeatherScenario.moderate,
    description: 'Strong Gust Winds warning',
    windSpeed: 12.5,
    precipitation: 45.0,
    statusText: 'Moderate gust risk. Manual oversight recommended.',
  );

  static const WeatherMockData dangerous = WeatherMockData(
    scenario: WeatherScenario.dangerous,
    description: 'Heavy Rain Thunderstorm',
    windSpeed: 24.5,
    precipitation: 95.0,
    statusText: 'Dangerous weather. Airspace closed. Flights blocked.',
  );
}
