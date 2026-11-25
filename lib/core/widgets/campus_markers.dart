import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The field-test drop-off (migration 42). Drawn with its own marker so in a
/// demo it reads at a glance as a test point, not a campus building.
const String kTestDropCode = 'TEST-DROP';

/// Whether a campus_locations row is the drone hub, an operational point and
/// never a drop-off.
bool isHubLocationCode(String code, [String name = '']) {
  final c = code.toUpperCase();
  return c == 'BASE-HUB' ||
      c == 'BASE_HUB' ||
      name.toLowerCase().contains('base hub');
}

/// A campus location marker, as the live map draws it. Shared by the radar and
/// the drop-off picker so both show the same thing.
///
/// The test drop-off ([isTestPoint]) is a rounded square with a white ring and
/// a flask icon instead of a circle with a building. Its colours follow the
/// same pickup / drop-off / idle rule as the rest.
class CampusMarkerPill extends StatelessWidget {
  final String code;
  final Color color;
  final bool isPickup;
  final bool isDropoff;
  final bool isTestPoint;

  const CampusMarkerPill({
    super.key,
    required this.code,
    required this.color,
    this.isPickup = false,
    this.isDropoff = false,
    this.isTestPoint = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            shape: isTestPoint ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: isTestPoint ? BorderRadius.circular(5) : null,
            border: isTestPoint
                ? Border.all(color: Colors.white, width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            isPickup
                ? Icons.storefront_rounded
                : isTestPoint
                ? Icons.science_rounded
                : isDropoff
                ? Icons.location_on_rounded
                : Icons.apartment_rounded,
            size: 12,
            color: AppColors.bgDark,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            code,
            style: AppTextStyles.caption(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// The drone hub marker, as the live map draws it.
class HubMarker extends StatelessWidget {
  const HubMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.hub_rounded,
            size: 14,
            color: AppColors.bgDark,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'BASE HUB',
            style: AppTextStyles.caption(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: AppColors.warning,
            ),
          ),
        ),
      ],
    );
  }
}
