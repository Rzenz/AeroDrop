import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers/delivery_zone_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/campus_markers.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_text_field.dart';

/// A drop-off point the customer placed on the map.
typedef PinnedDropoff = ({double lat, double lng, String? label});

/// Longest description the customer may give the spot.
const int kDropoffLabelMaxLength = 80;

/// What the picker returns: a campus location when one of its markers was
/// tapped, or a pin when open ground was.
sealed class DropoffPick {
  const DropoffPick();
}

/// A campus drop-off point, chosen by tapping its marker. It goes on the order
/// as delivery_location_id, never as coordinates, so the order keeps its link
/// to the building and the vendor sees its name.
class DropoffPickLocation extends DropoffPick {
  final CampusLocation location;
  const DropoffPickLocation(this.location);
}

/// A point on open ground the customer pinned.
class DropoffPickPin extends DropoffPick {
  final PinnedDropoff pin;
  const DropoffPickPin(this.pin);
}

/// Full-screen map for choosing a drop-off inside the delivery [zone].
///
/// Every campus location in [locations] is drawn with the live map's markers.
/// Tapping a building selects it as a fixed drop-off; tapping open ground
/// places or moves a pin. The hub is shown greyed and ignores taps. The circle
/// and the distance shown here are a guide for the customer; the server
/// decides whether a pin is allowed when the order is quoted and placed.
class DropoffMapPicker extends StatefulWidget {
  final DeliveryZone zone;
  final PinnedDropoff? initial;

  /// The campus_locations rows, hub included.
  final List<CampusLocation> locations;

  const DropoffMapPicker({
    super.key,
    required this.zone,
    this.initial,
    this.locations = const [],
  });

  /// Opens the picker and returns the confirmed choice, or null if dismissed.
  static Future<DropoffPick?> open(
    BuildContext context, {
    required DeliveryZone zone,
    PinnedDropoff? initial,
    List<CampusLocation> locations = const [],
  }) {
    return Navigator.of(context).push<DropoffPick>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DropoffMapPicker(
          zone: zone,
          initial: initial,
          locations: locations,
        ),
      ),
    );
  }

  @override
  State<DropoffMapPicker> createState() => _DropoffMapPickerState();
}

class _DropoffMapPickerState extends State<DropoffMapPicker> {
  // Great-circle distance, the same method the server's zone check uses
  static const _distance = Distance(calculator: Haversine());

  late final TextEditingController _label = TextEditingController(
    text: widget.initial?.label ?? '',
  );
  late LatLng? _pin = widget.initial == null
      ? null
      : LatLng(widget.initial!.lat, widget.initial!.lng);

  /// A building selected by tapping its marker. Exclusive with [_pin].
  CampusLocation? _location;

  LatLng get _center =>
      LatLng(widget.zone.centerLatitude, widget.zone.centerLongitude);

  /// The circle's bounding box with a margin, for the first view and to stop
  /// the map being dragged away from campus.
  LatLngBounds _boundsFor(double factor) {
    final r = widget.zone.radiusMeters * factor;
    return LatLngBounds.fromPoints([
      _distance.offset(_center, r, 0),
      _distance.offset(_center, r, 90),
      _distance.offset(_center, r, 180),
      _distance.offset(_center, r, -90),
    ]);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _confirmPin(LatLng pin) {
    final label = _label.text.trim();
    Navigator.of(context).pop<DropoffPick>(
      DropoffPickPin((
        lat: pin.latitude,
        lng: pin.longitude,
        label: label.isEmpty ? null : label,
      )),
    );
  }

  void _confirmLocation(CampusLocation location) =>
      Navigator.of(context).pop<DropoffPick>(DropoffPickLocation(location));

  /// The campus markers, as the live map draws them. A building marker selects
  /// that building; the hub is greyed and swallows its taps, so tapping it
  /// neither selects it nor drops a pin underneath.
  ///
  /// The hub is listed first so it is painted underneath: it sits 26 m from
  /// Maritime, and at the zoom that fits the circle the two overlap. Drawn on
  /// top, the hub would swallow taps meant for Maritime.
  List<Marker> _campusMarkers() {
    final hub = <Marker>[];
    final markers = <Marker>[];
    for (final loc in widget.locations) {
      if (loc.latitude == 0 && loc.longitude == 0) continue;
      final point = LatLng(loc.latitude, loc.longitude);
      if (isHubLocationCode(loc.locationCode, loc.name)) {
        hub.add(
          Marker(
            point: point,
            width: 68,
            height: 56,
            // Centered, so only the drawn marker takes taps, not the whole
            // slot the map gives it
            child: Center(
              child: Semantics(
                label: '${loc.name}, the drone hub, not a drop-off point',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const Opacity(opacity: 0.4, child: HubMarker()),
                ),
              ),
            ),
          ),
        );
        continue;
      }
      final selected = _location?.id == loc.id;
      markers.add(
        Marker(
          point: point,
          width: 64,
          height: 56,
          child: Center(
            child: Semantics(
              button: true,
              selected: selected,
              label: loc.name,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _location = loc;
                  _pin = null;
                }),
                child: CampusMarkerPill(
                  code: loc.locationCode,
                  color: selected ? AppColors.accent : Colors.white70,
                  isDropoff: selected,
                  isTestPoint: loc.locationCode == kTestDropCode,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return [...hub, ...markers];
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;
    final pin = _pin;
    final location = _location;
    final meters = pin == null ? null : _distance.distance(_center, pin);
    final outside = meters != null && meters > zone.radiusMeters;
    final pinColor = outside ? AppColors.danger : AppColors.success;

    final String readout;
    if (location != null) {
      readout = '${location.name}: a campus drop-off point.';
    } else if (meters == null) {
      readout =
          'Tap a building to choose it, or tap open ground inside the '
          'circle to place a pin.';
    } else if (outside) {
      readout =
          'Outside the delivery area: ${meters.round()} m from '
          '${zone.centerName}, and the limit is ${zone.radiusMeters.round()} m.';
    } else {
      readout =
          '${meters.round()} m from ${zone.centerName}. Inside the delivery area.';
    }

    return Scaffold(
      backgroundColor: AppColors.base,
      appBar: const CustomAppBar(title: 'Pin your drop-off'),
      body: Column(
        children: [
          // The map sits directly in the Column: FlutterMap must not be built
          // inside a LayoutBuilder.
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: _boundsFor(1.15),
                  padding: const EdgeInsets.all(24),
                ),
                minZoom: 15,
                maxZoom: 20,
                cameraConstraint: CameraConstraint.containCenter(
                  bounds: _boundsFor(2.5),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, point) => setState(() {
                  _pin = point;
                  _location = null;
                }),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ph.edu.uclm.aerodrop',
                  maxNativeZoom: 19,
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _center,
                      radius: zone.radiusMeters,
                      useRadiusInMeter: true,
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderColor: AppColors.accent,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(markers: _campusMarkers()),
                if (pin != null)
                  MarkerLayer(
                    markers: [
                      // Sits above its point, so the tip marks the spot at
                      // every zoom level
                      Marker(
                        point: pin,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 44,
                          color: pinColor,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 6),
                          ],
                          semanticLabel: outside
                              ? 'Pin, outside the delivery area'
                              : 'Pin, inside the delivery area',
                        ),
                      ),
                    ],
                  ),
                // The map data's credit. Built here rather than with
                // SimpleAttributionWidget, whose unflexed row can overflow a
                // narrow phone.
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    color: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageGutter(context),
                AppSpacing.sm,
                AppSpacing.pageGutter(context),
                AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        outside
                            ? Icons.error_outline_rounded
                            : Icons.place_outlined,
                        size: 18,
                        color: outside
                            ? AppColors.danger
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      // Wraps on a narrow phone rather than truncating
                      Expanded(
                        child: Text(
                          readout,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(
                            fontSize: 13,
                            fontWeight: outside
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: outside
                                ? AppColors.danger
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // A building already has a name; only a pin is described
                  if (location == null) ...[
                    NeuTextField(
                      labelText: 'Describe the spot (optional)',
                      hintText: 'e.g. by the side gate',
                      controller: _label,
                      maxLength: kDropoffLabelMaxLength,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  NeuButton(
                    text: 'Confirm drop-off',
                    icon: Icons.check_rounded,
                    onPressed: location != null
                        ? () => _confirmLocation(location)
                        : pin == null || outside
                        ? null
                        : () => _confirmPin(pin),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
