import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/animated_fab.dart';
import '../../core/widgets/custom_text_field.dart';

class NoFlyZonePage extends ConsumerStatefulWidget {
  const NoFlyZonePage({super.key});

  @override
  ConsumerState<NoFlyZonePage> createState() => _NoFlyZonePageState();
}

class _NoFlyZonePageState extends ConsumerState<NoFlyZonePage> {
  final List<Map<String, String>> _zones = [
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

  void _deleteZone(String id) {
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
  }

  void _showCreateZoneDialog(BuildContext context) {
    final nameController = TextEditingController();
    final radiusController = TextEditingController(text: '50m');
    final coordsController = TextEditingController(text: '10.3295° N, 123.9530° E');
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Restricted Zone', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(labelText: 'Zone Name', hintText: 'e.g. Science Lab Wing', controller: nameController),
              const SizedBox(height: 12),
              CustomTextField(labelText: 'Radius', hintText: 'e.g. 50m', controller: radiusController),
              const SizedBox(height: 12),
              CustomTextField(labelText: 'GPS Coordinates', hintText: 'Lat, Lng', controller: coordsController),
              const SizedBox(height: 12),
              CustomTextField(labelText: 'Reason for Restriction', hintText: 'e.g. Construction crane hazard', controller: reasonController),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (nameController.text.isEmpty || reasonController.text.isEmpty) return;
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
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('New geofence restriction active!'), backgroundColor: AppColors.success),
              );
            },
            child: const Text('Save Zone', style: TextStyle(color: AppColors.bgDark, fontWeight: FontWeight.bold)),
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
        title: Text('Edit Geofence ${zone['id']}', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(labelText: 'Zone Name', hintText: '', controller: nameController),
              const SizedBox(height: 12),
              CustomTextField(labelText: 'Radius', hintText: '', controller: radiusController),
              const SizedBox(height: 12),
              CustomTextField(labelText: 'GPS Coordinates', hintText: '', controller: coordsController),
              const SizedBox(height: 12),
              CustomTextField(labelText: 'Reason for Restriction', hintText: '', controller: reasonController),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
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
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restriction parameters updated!'), backgroundColor: AppColors.success),
              );
            },
            child: const Text('Update parameters', style: TextStyle(color: AppColors.bgDark, fontWeight: FontWeight.bold)),
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
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Geofence Constraints',
                      style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 32),

                // Subtitle helper info
                Text(
                  'Drones will automatically route around these active geofenced areas on campus.',
                  style: AppTextStyles.body(fontSize: 13, color: AppColors.textSecondaryDark),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 20),

                // List
                Expanded(
                  child: _zones.isEmpty
                      ? Center(
                          child: Text(
                            'No restricted airspace configured.',
                            style: TextStyle(color: AppColors.textSecondaryDark),
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
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.block_rounded, color: AppColors.danger, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              name,
                                              style: AppTextStyles.title(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                        StatusChip(
                                          label: id,
                                          color: AppColors.danger,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(Icons.radar_rounded, 'Radius', zone['radius']!),
                                    const SizedBox(height: 6),
                                    _buildInfoRow(Icons.location_on_outlined, 'Geocenter', zone['coords']!),
                                    const SizedBox(height: 6),
                                    _buildInfoRow(Icons.error_outline_rounded, 'Reason', reason),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _showEditZoneDialog(context, zone),
                                          icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.secondary),
                                          label: const Text('Edit Parameters', style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () => _deleteZone(id),
                                          icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.danger),
                                          label: const Text('Remove', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ).animate(delay: Duration(milliseconds: index * 60))
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
          style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark, fontWeight: FontWeight.bold),
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
