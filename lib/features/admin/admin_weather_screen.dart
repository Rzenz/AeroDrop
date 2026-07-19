import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_button.dart';
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
      // Auto-populate some sensible defaults to assist admin if empty
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

    final temp = double.tryParse(_tempController.text);
    final wind = double.tryParse(_windController.text);

    setState(() {
      _submitting = true;
      _statusError = null;
    });

    final currentWeather = ref.read(weatherProvider);

    final payload = {
      'safety_status': _safetyStatus,
      'condition': _conditionController.text,
      'temperature': temp,
      'wind_speed': wind,
      'message': _messageController.text,
    };

    // Debug logs
    debugPrint('[WEATHER UPDATE] Selected Status: $_safetyStatus');
    debugPrint('[WEATHER UPDATE] Current ID: ${currentWeather.id}');
    debugPrint('[WEATHER UPDATE] Payload: $payload');

    try {
      final client = Supabase.instance.client;
      Map<String, dynamic> returnedRow;

      if (currentWeather.id == null) {
        // Double check in DB just in case one got inserted after last fetch
        final check = await client
            .from('weather_safety')
            .select()
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (check != null) {
          debugPrint(
            '[WEATHER UPDATE] Found existing row during fallback check: ${check['id']}',
          );
          final res = await client
              .from('weather_safety')
              .update(payload)
              .eq('id', check['id'])
              .select()
              .single();
          returnedRow = res;
        } else {
          debugPrint('[WEATHER UPDATE] Inserting new weather row');
          final res = await client
              .from('weather_safety')
              .insert(payload)
              .select()
              .single();
          returnedRow = res;
        }
      } else {
        debugPrint(
          '[WEATHER UPDATE] Updating existing weather row: ${currentWeather.id}',
        );
        final res = await client
            .from('weather_safety')
            .update(payload)
            .eq('id', currentWeather.id!)
            .select()
            .single();
        returnedRow = res;
      }

      debugPrint('[WEATHER UPDATE] Returned DB row: $returnedRow');

      // Verify the safety_status matches
      final returnedStatus = returnedRow['safety_status']?.toString();
      if (returnedStatus != _safetyStatus) {
        debugPrint(
          '[WEATHER UPDATE ERROR] Safety status mismatch: expected $_safetyStatus, got $returnedStatus',
        );
        throw Exception('Safety status mismatch in returned database row.');
      }

      // Invalidate provider and await reload
      ref.invalidate(weatherProvider);
      await ref.read(weatherProvider.notifier).loadWeatherSafety();

      final refetched = ref.read(weatherProvider);
      debugPrint(
        '[WEATHER UPDATE] Provider refetched state: safetyStatus=${refetched.safetyStatus}, updatedAt=${refetched.updatedAt}',
      );

      if (refetched.safetyStatus != _safetyStatus) {
        throw Exception(
          'Refetched provider state does not match the updated status.',
        );
      }

      if (mounted) {
        setState(() {
          _submitting = false;
        });

        final statusDisplay = _safetyStatus == 'safe'
            ? 'Safe'
            : (_safetyStatus == 'caution' ? 'Caution' : 'Grounded');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Weather updated to $statusDisplay.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[WEATHER UPDATE EXCEPTION] $e');
      String displayMsg = 'Unable to update weather.';
      if (e is PostgrestException) {
        debugPrint(
          '[WEATHER UPDATE Supabase Error] Code: ${e.code}, Message: ${e.message}, Hint: ${e.hint}',
        );
        displayMsg = 'Unable to update weather: ${e.message}';
      }

      if (mounted) {
        setState(() {
          _submitting = false;
          _statusError = displayMsg;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to confirm the weather update.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
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
              const SizedBox(height: 24),

              // Current Status Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
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
                          const Text(
                            'Active Safety Level',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            weather.safetyStatus.toUpperCase(),
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
