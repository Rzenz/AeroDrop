import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/neu_back_button.dart';
import '../../core/providers/weather_provider.dart';

class AdminWeatherScreen extends ConsumerStatefulWidget {
  const AdminWeatherScreen({super.key});

  @override
  ConsumerState<AdminWeatherScreen> createState() => _AdminWeatherScreenState();
}

class _AdminWeatherScreenState extends ConsumerState<AdminWeatherScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _safetyStatus;
  late TextEditingController _conditionController;
  late TextEditingController _tempController;
  late TextEditingController _windController;
  late TextEditingController _messageController;
  bool _submitting = false;
  bool _resumingLive = false;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    final weather = ref.read(weatherProvider);
    _safetyStatus = weather.safetyStatus;
    _conditionController = TextEditingController(text: weather.condition ?? '');
    _tempController = TextEditingController(
      text: weather.temperature != null
          ? weather.temperature!.toStringAsFixed(1)
          : '',
    );
    _windController = TextEditingController(
      text: weather.windSpeed != null
          ? weather.windSpeed!.toStringAsFixed(1)
          : '',
    );
    _messageController = TextEditingController(text: weather.message ?? '');
  }

  @override
  void dispose() {
    _conditionController.dispose();
    _tempController.dispose();
    _windController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _setStatus(String status) {
    setState(() {
      _safetyStatus = status;
      // Auto-populate sensible defaults to assist admin
      if (_conditionController.text.isEmpty ||
          _conditionController.text == 'Clear Skies' ||
          _conditionController.text == 'High Winds' ||
          _conditionController.text == 'Heavy Rain') {
        _conditionController.text = status == 'safe'
            ? 'Clear Skies'
            : (status == 'caution' ? 'High Winds' : 'Heavy Rain');
      }
      if (_tempController.text.isEmpty ||
          _tempController.text == '30.0' ||
          _tempController.text == '32.0' ||
          _tempController.text == '22.0') {
        _tempController.text = status == 'safe'
            ? '30.0'
            : (status == 'caution' ? '32.0' : '22.0');
      }
      if (_windController.text.isEmpty ||
          _windController.text == '10.0' ||
          _windController.text == '28.0' ||
          _windController.text == '40.0') {
        _windController.text = status == 'safe'
            ? '10.0'
            : (status == 'caution' ? '28.0' : '40.0');
      }
      if (_messageController.text.isEmpty ||
          _messageController.text ==
              'Weather conditions are safe for campus drone dispatch.' ||
          _messageController.text ==
              'Delivery may be delayed due to caution-level weather conditions.' ||
          _messageController.text ==
              'Weather is currently unsafe for drone delivery. Please try again later.') {
        _messageController.text = status == 'safe'
            ? 'Weather conditions are safe for campus drone dispatch.'
            : (status == 'caution'
                  ? 'Delivery may be delayed due to caution-level weather conditions.'
                  : 'Weather is currently unsafe for drone delivery. Please try again later.');
      }
    });
  }

  Future<void> _submitWeather() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _statusError = null;
    });

    try {
      final success = await ref
          .read(weatherProvider.notifier)
          .setSimulatedWeather(_safetyStatus, durationHours: 2.0);

      if (!success) {
        throw Exception('Server returned false on weather simulation.');
      }

      if (mounted) {
        final statusDisplay = _safetyStatus == 'safe'
            ? 'Safe'
            : (_safetyStatus == 'caution' ? 'Caution' : 'Grounded');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Weather override applied: $statusDisplay (2 hours).'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[WEATHER OVERRIDE EXCEPTION] $e');
      if (mounted) {
        setState(() {
          _statusError = 'Unable to set weather override: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to apply weather override: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _resumeLiveWeather() async {
    setState(() {
      _resumingLive = true;
      _statusError = null;
    });

    try {
      final success = await ref
          .read(weatherProvider.notifier)
          .clearWeatherOverride();

      if (!success) {
        throw Exception('Server returned false on clearing weather override.');
      }

      if (mounted) {
        final weather = ref.read(weatherProvider);
        setState(() {
          _safetyStatus = weather.safetyStatus;
          _conditionController.text = weather.condition ?? '';
          _tempController.text = weather.temperature != null
              ? weather.temperature!.toStringAsFixed(1)
              : '';
          _windController.text = weather.windSpeed != null
              ? weather.windSpeed!.toStringAsFixed(1)
              : '';
          _messageController.text = weather.message ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Live campus weather resumed.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[CLEAR WEATHER OVERRIDE EXCEPTION] $e');
      if (mounted) {
        setState(() {
          _statusError = 'Failed to resume live weather: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resume live weather: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _resumingLive = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = ref.watch(weatherProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        leading: const NeuBackButton(
          fallbackRoute: '/admin',
          color: AppColors.cardDark,
          iconColor: Colors.white,
        ),
        title: Text(
          'Campus Weather Controls',
          style: AppTextStyles.subHead(fontSize: 18, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Flight Safety Parameters',
                style: AppTextStyles.title(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Configure drone dispatch constraints based on campus weather observations.',
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 20),

              // 1. Data Stale Warning Note (Admin only)
              if (weather.isDataStale) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          weather.staleWarningMessage ?? 'Weather data may be out of date.',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2. Active Status & Override Card
              if (weather.isOverrideActive)
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            weather.safetyStatus == 'safe'
                                ? Icons.wb_sunny_rounded
                                : (weather.safetyStatus == 'caution'
                                      ? Icons.air_rounded
                                      : Icons.thunderstorm_rounded),
                            color: weather.safetyStatus == 'safe'
                                ? AppColors.accent
                                : (weather.safetyStatus == 'caution'
                                      ? AppColors.warning
                                      : AppColors.danger),
                            size: 32,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'OVERRIDE ACTIVE',
                                        style: TextStyle(
                                          color: AppColors.warning,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      weather.overrideRemainingText,
                                      style: const TextStyle(
                                        color: AppColors.textSecondaryDark,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manual: ${weather.safetyStatus.toUpperCase()} - ${weather.overrideRemainingText}',
                                  style: TextStyle(
                                    color: weather.safetyStatus == 'safe'
                                        ? AppColors.success
                                        : (weather.safetyStatus == 'caution'
                                              ? AppColors.warning
                                              : AppColors.danger),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),
                      // REAL conditions underneath
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ACTUAL CAMPUS WEATHER',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondaryDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(weather.realSafetyStatus ?? 'safe').toUpperCase()} • ${weather.realCondition ?? 'Clear Sky'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${weather.temperatureDisplay} • ${weather.windDisplay}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Resume live weather button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _resumingLive ? null : _resumeLiveWeather,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: const BorderSide(color: AppColors.accent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _resumingLive
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accent,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded, size: 18),
                          label: Text(
                            _resumingLive ? 'Resuming...' : 'Resume Live Weather',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            weather.safetyStatus == 'safe'
                                ? Icons.wb_sunny_rounded
                                : (weather.safetyStatus == 'caution'
                                      ? Icons.air_rounded
                                      : Icons.thunderstorm_rounded),
                            color: weather.safetyStatus == 'safe'
                                ? AppColors.accent
                                : (weather.safetyStatus == 'caution'
                                      ? AppColors.warning
                                      : AppColors.danger),
                            size: 32,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'LIVE TELEMETRY',
                                        style: TextStyle(
                                          color: AppColors.success,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        weather.lastUpdatedText,
                                        style: const TextStyle(
                                          color: AppColors.textSecondaryDark,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${weather.safetyStatus.toUpperCase()} — ${weather.condition ?? 'Clear Sky'}',
                                  style: TextStyle(
                                    color: weather.safetyStatus == 'safe'
                                        ? AppColors.success
                                        : (weather.safetyStatus == 'caution'
                                              ? AppColors.warning
                                              : AppColors.danger),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Temp: ${weather.temperatureDisplay}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Wind: ${weather.windDisplay}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Safety Selector Row
              Text(
                'Set Dispatch Condition',
                style: AppTextStyles.subHead(
                  fontSize: 14,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildStatusButton(
                    'safe',
                    'SAFE',
                    AppColors.success,
                    Icons.check_circle_outline_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusButton(
                    'caution',
                    'CAUTION',
                    AppColors.warning,
                    Icons.warning_amber_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusButton(
                    'grounded',
                    'GROUNDED',
                    AppColors.danger,
                    Icons.block_flipped,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Inputs inside GlassCard
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CustomTextField(
                      labelText: 'Condition Summary',
                      hintText: 'e.g. Clear Skies',
                      controller: _conditionController,
                      prefixIcon: Icons.wb_cloudy_outlined,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Condition is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            labelText: 'Temperature (°C)',
                            hintText: 'e.g. 30.0',
                            controller: _tempController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            prefixIcon: Icons.thermostat_rounded,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(val) == null) {
                                return 'Must be numeric';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            labelText: 'Wind Speed (km/h)',
                            hintText: 'e.g. 12.5',
                            controller: _windController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            prefixIcon: Icons.wind_power_rounded,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(val) == null) {
                                return 'Must be numeric';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      labelText: 'Advisory Message',
                      hintText:
                          'Advisory for drone pilots, merchants and students...',
                      controller: _messageController,
                      prefixIcon: Icons.feedback_outlined,
                      maxLines: 2,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Message is required'
                          : null,
                    ),
                  ],
                ),
              ),

              if (_statusError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _statusError!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              const SizedBox(height: 32),
              CustomButton(
                text: 'Publish Weather Constraints',
                icon: Icons.publish_rounded,
                isLoading: _submitting,
                onPressed: _submitting ? null : _submitWeather,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusButton(
    String status,
    String label,
    Color color,
    IconData icon,
  ) {
    final isSelected = _safetyStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setStatus(status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? color : AppColors.textSecondaryDark,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : AppColors.textSecondaryDark,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
