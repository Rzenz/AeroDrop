import '../core/models/notification_model.dart';

final List<NotificationModel> mockNotifications = [
  NotificationModel(
    id: 'ntf-1',
    title: 'Drone DRN-001 Dispatched',
    body: 'Your delivery request ADR-2026-00101 has been dispatched via AeroCarrier Falcon.',
    timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    isRead: false,
  ),
  NotificationModel(
    id: 'ntf-2',
    title: 'Delivery ADR-2026-00102 Delivered',
    body: 'SkyLifter Titan has successfully delivered package "Confidential Document Envelopes" to Main Library Lobby.',
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    isRead: true,
  ),
  NotificationModel(
    id: 'ntf-3',
    title: 'System Alert: Maintenance',
    body: 'Drone DRN-003 is flagged for battery calibration and scheduled maintenance.',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    isRead: true,
  ),
  ...List.generate(28, (index) {
    final id = index + 4;
    return NotificationModel(
      id: 'ntf-$id',
      title: 'Alert Update #$id',
      body: 'Standard simulated flight operation audit check. Mission telemetry log verified for corridor $id.',
      timestamp: DateTime.now().subtract(Duration(hours: index + 4)),
      isRead: index % 3 == 0,
    );
  })
];
