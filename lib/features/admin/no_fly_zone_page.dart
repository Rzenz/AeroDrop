import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/animated_fab.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/neu_back_button.dart';

class NoFlyZonePage extends ConsumerStatefulWidget {
  const NoFlyZonePage({super.key});

  @override
  ConsumerState<NoFlyZonePage> createState() => _NoFlyZonePageState();
}

class _NoFlyZonePageState extends ConsumerState<NoFlyZonePage> {
  List<Map<String, String>> _zones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchZones();
  }

  Future<void> _fetchZones() async {
    if (!mounted) return;
    if (!SupabaseService.isConfigured) {
      setState(() {
        _zones = [
          {
            'id': 'NFZ-101',
            'name': 'Gymnasium Dome',
            'radius': '75m',
            'coords': '10.3282° N, 123.9515° E',
            'reason': 'Indoor activities, structural height risk',
            'status': 'active',
          },
          {
            'id': 'NFZ-102',
            'name': 'University Grandstand',
            'radius': '100m',
            'coords': '10.3290° N, 123.9520° E',
            'reason': 'High student assembly density, open sports area',
            'status': 'active',
          },
          {
            'id': 'NFZ-103',
            'name': 'Power Station Grid',
            'radius': '50m',
            'coords': '10.3260° N, 123.9490° E',
            'reason': 'Magnetic frequency interference risk',
            'status': 'active',
          },
        ];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await SupabaseService.client
          .from('no_fly_zones')
          .select()
          .eq('is_active', true);

      final List<Map<String, String>> loadedZones = [];
      for (final item in res) {
        loadedZones.add({
          'id': item['id']?.toString() ?? '',
          'name': item['name']?.toString() ?? '',
          'radius': '${item['radius_meters']?.toString() ?? '50'}m',
          'coords': '${item['latitude']}, ${item['longitude']}',
          'reason': item['reason']?.toString() ?? '',
          'status': (item['is_active'] as bool? ?? true)
              ? 'active'
              : 'inactive',
        });
      }
      if (mounted) {
        setState(() {
          _zones = loadedZones;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching no fly zones: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteZone(String id) async {
    if (!SupabaseService.isConfigured) {
      setState(() {
        _zones.removeWhere((z) => z['id'] == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Geofence zone $id deleted!'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await SupabaseService.client
          .from('no_fly_zones')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Restricted airspace zone set to Inactive successfully!',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchZones();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to deactivate zone: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCreateZoneDialog(BuildContext context) {
    final nameController = TextEditingController();
    final radiusController = TextEditingController(text: '50m');
    final coordsController = TextEditingController(text: '10.3295, 123.9530');
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'New Restricted Zone',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                labelText: 'Zone Name',
                hintText: 'e.g. Science Lab Wing',
                controller: nameController,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                labelText: 'Radius',
                hintText: 'e.g. 50m',
                controller: radiusController,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                labelText: 'GPS Coordinates',
                hintText: 'Lat, Lng',
                controller: coordsController,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                labelText: 'Reason for Restriction',
                hintText: 'e.g. Construction crane hazard',
                controller: reasonController,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  reasonController.text.isEmpty) {
                return;
              }
              Navigator.pop(ctx);

              if (!SupabaseService.isConfigured) {
                setState(() {
                  _zones.add({
                    'id': 'NFZ-${100 + _zones.length + 1}',
                    'name': nameController.text,
                    'radius': radiusController.text,
                    'coords': coordsController.text,
                    'reason': reasonController.text,
                    'status': 'active',
                  });
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New geofence restriction active!'),
                    backgroundColor: AppColors.success,
                  ),
                );
                return;
              }

              try {
                final radStr = radiusController.text.replaceAll('m', '').trim();
                final radius = double.tryParse(radStr) ?? 50.0;

                double lat = 10.3295;
                double lng = 123.9530;
                final cleanCoords = coordsController.text
                    .replaceAll('° N', '')
                    .replaceAll('° E', '')
                    .replaceAll('N', '')
                    .replaceAll('E', '')
                    .trim();
                final parts = cleanCoords.split(',');
                if (parts.length == 2) {
                  lat = double.tryParse(parts[0].trim()) ?? 10.3295;
                  lng = double.tryParse(parts[1].trim()) ?? 123.9530;
                }

                await SupabaseService.client.from('no_fly_zones').insert({
                  'name': nameController.text,
                  'radius_meters': radius,
                  'latitude': lat,
                  'longitude': lng,
                  'reason': reasonController.text,
                  'is_active': true,
                });

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New restricted zone saved!'),
                    backgroundColor: AppColors.success,
                  ),
                );
                _fetchZones();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save zone: $e'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            child: const Text(
              'Save Zone',
              style: TextStyle(
                color: AppColors.bgDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditZoneDialog(BuildContext context, Map<String, String> zone) {
    final nameController = TextEditingController(text: zone['name']);
    final radiusController = TextEditingController(text: zone['radius']);
    final coordsController = TextEditingController(text: zone['coords']);
    final reasonController = TextEditingController(text: zone['reason']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Geofence ${zone['id']}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                labelText: 'Zone Name',
                hintText: '',
                controller: nameController,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                labelText: 'Radius',
                hintText: '',
                controller: radiusController,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                labelText: 'GPS Coordinates',
                hintText: '',
                controller: coordsController,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                labelText: 'Reason for Restriction',
                hintText: '',
                controller: reasonController,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              if (!SupabaseService.isConfigured) {
                setState(() {
                  final idx = _zones.indexWhere((z) => z['id'] == zone['id']);
                  if (idx != -1) {
                    _zones[idx] = {
                      ..._zones[idx],
                      'name': nameController.text,
                      'radius': radiusController.text,
                      'coords': coordsController.text,
                      'reason': reasonController.text,
                    };
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Restriction parameters updated!'),
                    backgroundColor: AppColors.success,
                  ),
                );
                return;
              }

              try {
                final radStr = radiusController.text.replaceAll('m', '').trim();
                final radius = double.tryParse(radStr) ?? 50.0;

                double lat = 10.3295;
                double lng = 123.9530;
                final cleanCoords = coordsController.text
                    .replaceAll('° N', '')
                    .replaceAll('° E', '')
                    .replaceAll('N', '')
                    .replaceAll('E', '')
                    .trim();
                final parts = cleanCoords.split(',');
                if (parts.length == 2) {
                  lat = double.tryParse(parts[0].trim()) ?? 10.3295;
                  lng = double.tryParse(parts[1].trim()) ?? 123.9530;
                }

                await SupabaseService.client
                    .from('no_fly_zones')
                    .update({
                      'name': nameController.text,
                      'radius_meters': radius,
                      'latitude': lat,
                      'longitude': lng,
                      'reason': reasonController.text,
                      'updated_at': DateTime.now().toUtc().toIso8601String(),
                    })
                    .eq('id', zone['id']!);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Restriction parameters updated!'),
                    backgroundColor: AppColors.success,
                  ),
                );
                _fetchZones();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update zone: $e'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            child: const Text(
              'Update parameters',
              style: TextStyle(
                color: AppColors.bgDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      floatingActionButton: AnimatedFAB(
        icon: Icons.add_rounded,
        tooltip: 'New Zone',
        onPressed: () => _showCreateZoneDialog(context),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const NeuBackButton(
                      fallbackRoute: '/admin',
                      color: AppColors.cardDark,
                      iconColor: Colors.white,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Geofence Constraints',
                      style: AppTextStyles.title(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 32),

                Text(
                  'Drones will automatically route around these active geofenced areas on campus.',
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 20),

                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        )
                      : _zones.isEmpty
                      ? Center(
                          child: Text(
                            'No no-fly zones configured.',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _zones.length,
                          itemBuilder: (context, index) {
                            final zone = _zones[index];
                            final id = zone['id']!;
                            final name = zone['name']!;
                            final reason = zone['reason']!;

                            return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: GlassCard(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.block_rounded,
                                                  color: AppColors.danger,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  name,
                                                  style: AppTextStyles.title(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            StatusChip(
                                              label: id.length > 8
                                                  ? id.substring(0, 8)
                                                  : id,
                                              color: AppColors.danger,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _buildInfoRow(
                                          Icons.radar_rounded,
                                          'Radius',
                                          zone['radius']!,
                                        ),
                                        const SizedBox(height: 6),
                                        _buildInfoRow(
                                          Icons.location_on_outlined,
                                          'Geocenter',
                                          zone['coords']!,
                                        ),
                                        const SizedBox(height: 6),
                                        _buildInfoRow(
                                          Icons.error_outline_rounded,
                                          'Reason',
                                          reason,
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _showEditZoneDialog(
                                                    context,
                                                    zone,
                                                  ),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 14,
                                                color: AppColors.secondary,
                                              ),
                                              label: const Text(
                                                'Edit Parameters',
                                                style: TextStyle(
                                                  color: AppColors.secondary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              onPressed: () => _deleteZone(id),
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 14,
                                                color: AppColors.danger,
                                              ),
                                              label: const Text(
                                                'Remove',
                                                style: TextStyle(
                                                  color: AppColors.danger,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .animate(
                                  delay: Duration(milliseconds: index * 60),
                                )
                                .fadeIn()
                                .slideY(begin: 0.05);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondaryDark, size: 14),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTextStyles.body(
            fontSize: 11,
            color: AppColors.textSecondaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
