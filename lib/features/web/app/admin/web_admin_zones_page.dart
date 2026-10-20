import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../web_kit.dart';

class _Zone {
  _Zone(this.id, this.name, this.radius, this.at, this.reason);
  final String id;
  final String name;
  final double radius;
  final LatLng at;
  final String reason;
}

/// Flight boundaries on the campus map. Each active no-fly zone is drawn
/// as its circle; a click on the map places a new zone's centre, and the
/// list beside the map edits and removes them. The same table writes as the
/// app — removing a zone marks it inactive.
class WebAdminZonesPage extends ConsumerStatefulWidget {
  const WebAdminZonesPage({super.key});

  @override
  ConsumerState<WebAdminZonesPage> createState() => _WebAdminZonesPageState();
}

class _WebAdminZonesPageState extends ConsumerState<WebAdminZonesPage> {
  static const _campus = LatLng(10.3255, 123.9539);

  final _map = MapController();
  List<_Zone> _zones = [];
  bool _loading = true;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!SupabaseService.isConfigured) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.client
          .from('no_fly_zones')
          .select()
          .eq('is_active', true);
      _zones = [
        for (final z in res)
          _Zone(
            z['id'].toString(),
            z['name']?.toString() ?? 'Zone',
            (z['radius_meters'] as num?)?.toDouble() ?? 50,
            LatLng(
              (z['latitude'] as num?)?.toDouble() ?? _campus.latitude,
              (z['longitude'] as num?)?.toDouble() ?? _campus.longitude,
            ),
            z['reason']?.toString() ?? '',
          ),
      ];
    } catch (e) {
      debugPrint('No-fly zones: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit({_Zone? zone, LatLng? at}) async {
    final name = TextEditingController(text: zone?.name ?? '');
    final radius = TextEditingController(
      text: (zone?.radius ?? 50).round().toString(),
    );
    final reason = TextEditingController(text: zone?.reason ?? '');
    final point = zone?.at ?? at ?? _campus;
    final form = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.base,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    zone == null ? 'New no-fly zone' : 'Edit ${zone.name}',
                    style: WebText.title(size: 19),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Centred at ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                    style: WebText.body(size: 13),
                  ),
                  const SizedBox(height: 18),
                  WebField(
                    label: 'Name',
                    controller: name,
                    hint: 'Gymnasium roof',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Name the zone' : null,
                  ),
                  const SizedBox(height: 14),
                  WebField(
                    label: 'Radius (metres)',
                    controller: radius,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final r = double.tryParse(v?.trim() ?? '');
                      return r == null || r <= 0
                          ? 'Enter a radius in metres'
                          : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  WebField(
                    label: 'Reason',
                    controller: reason,
                    hint: 'Event, construction, crowd…',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      WebButton(
                        label: 'Cancel',
                        kind: WebButtonKind.secondary,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                      const SizedBox(width: 12),
                      WebButton(
                        label: zone == null ? 'Add zone' : 'Save',
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            Navigator.pop(ctx, true);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final row = {
      'name': name.text.trim(),
      'radius_meters': double.parse(radius.text.trim()),
      'latitude': point.latitude,
      'longitude': point.longitude,
      'reason': reason.text.trim(),
    };
    try {
      final table = SupabaseService.client.from('no_fly_zones');
      if (zone == null) {
        await table.insert({...row, 'is_active': true});
      } else {
        await table
            .update({
              ...row,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', zone.id);
      }
      if (!mounted) return;
      showNeuSnack(
        context,
        zone == null ? 'Zone added.' : 'Zone saved.',
        tone: NeuToneKind.success,
      );
      _fetch();
    } catch (e) {
      if (mounted) {
        showNeuSnack(
          context,
          'Could not save the zone: $e',
          tone: NeuToneKind.error,
        );
      }
    }
  }

  Future<void> _remove(_Zone z) async {
    final ok = await showNeuConfirm(
      context,
      title: 'Lift ${z.name}?',
      message: 'Drones may fly through it again. It is kept, marked inactive.',
      confirmLabel: 'Lift restriction',
      destructive: true,
      icon: Icons.layers_clear_outlined,
    );
    if (!ok || !mounted) return;
    try {
      await SupabaseService.client
          .from('no_fly_zones')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', z.id);
      if (!mounted) return;
      showNeuSnack(context, '${z.name} lifted.', tone: NeuToneKind.success);
      _fetch();
    } catch (e) {
      if (mounted) {
        showNeuSnack(
          context,
          'Could not lift the zone: $e',
          tone: NeuToneKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final map = NeuSurface(
      depth: NeuDepth.medium,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _campus,
                initialZoom: 17.4,
                minZoom: 15,
                maxZoom: 20,
                onTap: (_, at) => _edit(at: at),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ph.edu.uclm.aerodrop',
                  maxNativeZoom: 19,
                ),
                CircleLayer(
                  circles: [
                    for (final z in _zones)
                      CircleMarker(
                        point: z.at,
                        radius: z.radius,
                        useRadiusInMeter: true,
                        color: AppColors.danger.withValues(
                          alpha: z.id == _selected ? 0.35 : 0.2,
                        ),
                        borderColor: AppColors.danger,
                        borderStrokeWidth: z.id == _selected ? 3 : 1.5,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final z in _zones)
                      Marker(
                        point: z.at,
                        width: 160,
                        height: 30,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              z.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: WebText.label(
                                size: 11.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                ),
              ],
            ),
            Positioned(
              left: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Click the map to add a zone there',
                  style: WebText.label(size: 12.5, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 24),
      children: [
        Text('ACTIVE ZONES', style: WebText.overline()),
        const SizedBox(height: 10),
        if (_loading)
          const WebSkeleton(height: 90)
        else if (_zones.isEmpty)
          const WebEmpty(
            icon: Icons.layers_outlined,
            title: 'No restricted airspace',
            message: 'Drones may fly anywhere over campus.',
          )
        else
          for (final z in _zones)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WebHoverCard(
                onTap: () {
                  setState(() => _selected = z.id);
                  _map.move(z.at, 18);
                },
                radius: 18,
                padding: const EdgeInsets.all(14),
                semanticLabel: '${z.name}, ${z.radius.round()} metres',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.do_not_disturb_on_outlined,
                          size: 18,
                          color: AppColors.readable(AppColors.danger),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(z.name, style: WebText.label(size: 14.5)),
                        ),
                        Text(
                          '${z.radius.round()} m',
                          style: WebText.label(size: 13),
                        ),
                      ],
                    ),
                    if (z.reason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(z.reason, style: WebText.body(size: 12.5)),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        WebButton(
                          label: 'Edit',
                          kind: WebButtonKind.ghost,
                          dense: true,
                          onPressed: () => _edit(zone: z),
                        ),
                        WebButton(
                          label: 'Lift',
                          kind: WebButtonKind.ghost,
                          dense: true,
                          onPressed: () => _remove(z),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );

    return WebPage.fill(
      title: 'Flight boundaries',
      subtitle:
          '${_zones.length} no-fly ${_zones.length == 1 ? 'zone' : 'zones'} over campus',
      actions: [
        WebButton(
          label: 'Add at campus centre',
          icon: Icons.add_location_alt_outlined,
          onPressed: () => _edit(at: _campus),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, box) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: box.maxWidth >= 900
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 340, child: list),
                    const SizedBox(width: 20),
                    Expanded(child: map),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: (box.maxHeight * 0.5).clamp(260.0, 420.0),
                      child: map,
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: list),
                  ],
                ),
        ),
      ),
    );
  }
}
