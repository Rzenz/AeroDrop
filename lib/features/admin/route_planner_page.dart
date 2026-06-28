import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/glass_card.dart';

class RoutePlannerPage extends StatefulWidget {
  const RoutePlannerPage({super.key});

  @override
  State<RoutePlannerPage> createState() => _RoutePlannerPageState();
}

class _RoutePlannerPageState extends State<RoutePlannerPage> {
  final List<Map<String, String>> _corridors = [
    {'name': 'Safe Corridor Alpha-1', 'from': 'Logistics Hub', 'to': 'Engineering Platform', 'status': 'Active'},
    {'name': 'Safe Corridor Beta-3', 'from': 'Logistics Hub', 'to': 'Science Building Annex', 'status': 'Active'},
    {'name': 'Safe Corridor Gamma-2', 'from': 'Logistics Hub', 'to': 'Main Quad Reception', 'status': 'Restricted'},
  ];

  String _selectedCorridor = 'Safe Corridor Alpha-1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
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
                      'Campus Flight Paths',
                      style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 24),

                // Mock Vector Campus Map Canvas
                Expanded(
                  flex: 3,
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Stack(
                      children: [
                        // Map background mesh representation
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.15,
                            child: GridPaper(
                              color: AppColors.secondary,
                              divisions: 2,
                              subdivisions: 4,
                            ),
                          ),
                        ),
                        // Campus landmark circles and vector connections
                        Center(
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _MapCorridorPainter(selectedCorridor: _selectedCorridor),
                          ),
                        ),
                        // Instruction label
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderDark),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.radar_rounded, color: AppColors.secondary, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'Interactive Autopilot Vectors',
                                  style: AppTextStyles.body(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                ),
                const SizedBox(height: 20),

                // Route Select Panel
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Column(
                      children: _corridors.map((c) {
                        final isSel = c['name'] == _selectedCorridor;
                        final isRestricted = c['status'] == 'Restricted';

                        return GestureDetector(
                          onTap: () => setState(() => _selectedCorridor = c['name']!),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.cardDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSel 
                                    ? AppColors.primary 
                                    : (isRestricted ? AppColors.danger.withValues(alpha: 0.4) : AppColors.borderDark),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isRestricted ? AppColors.danger : AppColors.secondary).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isRestricted ? Icons.block_rounded : Icons.route_rounded,
                                    color: isRestricted ? AppColors.danger : AppColors.secondary,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c['name']!,
                                        style: AppTextStyles.title(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      Text(
                                        'From ${c['from']} to ${c['to']}',
                                        style: AppTextStyles.body(fontSize: 10, color: AppColors.textSecondaryDark),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isRestricted ? AppColors.danger : AppColors.success).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    c['status']!.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isRestricted ? AppColors.danger : AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ),

                // Button
                CustomButton(
                  text: 'Configure Geofence Constraints',
                  icon: Icons.shield_outlined,
                  onPressed: () => context.push('/admin/routes/no-fly-zones'),
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapCorridorPainter extends CustomPainter {
  final String selectedCorridor;
  _MapCorridorPainter({required this.selectedCorridor});

  @override
  void paint(Canvas canvas, Size size) {
    final hub = Offset(size.width * 0.2, size.height * 0.5);
    final eng = Offset(size.width * 0.8, size.height * 0.25);
    final sci = Offset(size.width * 0.75, size.height * 0.75);
    final quad = Offset(size.width * 0.55, size.height * 0.45);

    // Node paints
    final nodePaint = Paint()
      ..color = AppColors.cardDark2
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.borderDark
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final activePathPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final pathPaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dangerPathPaint = Paint()
      ..color = AppColors.danger.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw connection lines
    canvas.drawLine(hub, eng, selectedCorridor.contains('Alpha-1') ? activePathPaint : pathPaint);
    canvas.drawLine(hub, sci, selectedCorridor.contains('Beta-3') ? activePathPaint : pathPaint);
    canvas.drawLine(hub, quad, selectedCorridor.contains('Gamma-2') ? activePathPaint : dangerPathPaint);

    // Draw nodes
    final nodes = [hub, eng, sci, quad];
    for (int i = 0; i < nodes.length; i++) {
      canvas.drawCircle(nodes[i], 16, nodePaint);
      canvas.drawCircle(nodes[i], 16, borderPaint);

      if (nodes[i] == hub) {
        canvas.drawCircle(nodes[i], 8, Paint()..color = AppColors.secondary);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
