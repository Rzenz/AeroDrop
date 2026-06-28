import '../core/models/delivery_model.dart';

final List<DeliveryModel> mockDeliveries = [
  DeliveryModel(
    id: 'ADR-2026-00101',
    senderName: 'UCLM Science Lab',
    recipientName: 'Engineering Bldg B',
    recipientPhone: '+63 912 345 6789',
    deliveryAddress: 'Engineering Hub Room 204',
    packageName: 'Microscope Slides & Samples',
    packageWeight: 1.2,
    packageType: 'Medicine',
    status: DeliveryStatus.inTransit,
    droneId: 'DRN-001',
    eta: '8 mins',
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    progress: 0.4,
  ),
  DeliveryModel(
    id: 'ADR-2026-00102',
    senderName: 'Admin Office',
    recipientName: 'Main Library Lobby',
    recipientPhone: '+63 998 765 4321',
    deliveryAddress: 'Library Reception Desk',
    packageName: 'Confidential Document Envelopes',
    packageWeight: 0.5,
    packageType: 'Document',
    status: DeliveryStatus.delivered,
    droneId: 'DRN-002',
    eta: '0 mins',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    progress: 1.0,
  ),
  DeliveryModel(
    id: 'ADR-2026-00103',
    senderName: 'Campus Canteen',
    recipientName: 'Student Pavilion',
    recipientPhone: '+63 945 111 2222',
    deliveryAddress: 'Pavilion Table 4',
    packageName: 'Warm Lunch Bento Boxes',
    packageWeight: 2.1,
    packageType: 'Food',
    status: DeliveryStatus.pending,
    droneId: null,
    eta: 'TBD',
    createdAt: DateTime.now(),
    progress: 0.0,
  ),
  // Generating remaining mock data elements up to 50
  ...List.generate(47, (index) {
    final id = 104 + index;
    final statuses = [DeliveryStatus.delivered, DeliveryStatus.cancelled, DeliveryStatus.pending];
    final status = statuses[index % statuses.length];
    final types = ['Document', 'Food', 'Medicine', 'Electronics'];
    final type = types[index % types.length];
    
    return DeliveryModel(
      id: 'ADR-2026-00$id',
      senderName: 'UCLM Dept ${index + 1}',
      recipientName: 'Recipient ${index + 1}',
      recipientPhone: '+63 900 000 ${1000 + index}',
      deliveryAddress: 'UCLM Bldg Pad ${index % 5 + 1}',
      packageName: 'Item Mock Pack ${index + 1}',
      packageWeight: (index % 4 + 1) * 0.8,
      packageType: type,
      status: status,
      droneId: status == DeliveryStatus.delivered ? 'DRN-005' : null,
      eta: status == DeliveryStatus.delivered ? '0 mins' : 'TBD',
      createdAt: DateTime.now().subtract(Duration(hours: index + 3)),
      progress: status == DeliveryStatus.delivered ? 1.0 : 0.0,
    );
  })
];
