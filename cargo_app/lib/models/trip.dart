import '../utils/constants.dart';

class Trip {
  final String id;
  final String driverId;
  final String vehicleId;
  final TripStatus status;
  final DateTime startTime;
  final double startLatitude;
  final double startLongitude;
  final List<TrackPoint> track;
  final DateTime? endTime;
  final double? endLatitude;
  final double? endLongitude;
  final double mileage;
  final MileageSource mileageSource;
  final double? manualMileage;
  final String? cargoDescription;
  final String? routeDescription;
  final double? income;
  final String? waybillUrl;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    required this.status,
    required this.startTime,
    required this.startLatitude,
    required this.startLongitude,
    this.track = const [],
    this.endTime,
    this.endLatitude,
    this.endLongitude,
    this.mileage = 0,
    this.mileageSource = MileageSource.auto,
    this.manualMileage,
    this.cargoDescription,
    this.routeDescription,
    this.income,
    this.waybillUrl,
    required this.createdAt,
  });

  factory Trip.fromMap(String id, Map<String, dynamic> data) {
    final trackRaw = data['track'] as List<dynamic>? ?? [];
    final track = trackRaw.map((pt) => TrackPoint.fromMap(pt)).toList();

    return Trip(
      id: id,
      driverId: data['driverId'] ?? '',
      vehicleId: data['vehicleId'] ?? '',
      status: _parseStatus(data['status'] ?? 'active'),
      startTime: (data['startTime'] as dynamic).toDate(),
      startLatitude: (data['startLocation']?['latitude'] ?? 0.0).toDouble(),
      startLongitude: (data['startLocation']?['longitude'] ?? 0.0).toDouble(),
      track: track,
      endTime: data['endTime'] != null ? (data['endTime'] as dynamic).toDate() : null,
      endLatitude: data['endLocation']?['latitude']?.toDouble(),
      endLongitude: data['endLocation']?['longitude']?.toDouble(),
      mileage: (data['mileage'] ?? 0.0).toDouble(),
      mileageSource: data['mileageSource'] == 'manual'
          ? MileageSource.manual
          : MileageSource.auto,
      manualMileage: data['manualMileage']?.toDouble(),
      cargoDescription: data['cargoDescription'],
      routeDescription: data['routeDescription'],
      income: data['income']?.toDouble(),
      waybillUrl: data['waybillUrl'],
      createdAt: (data['createdAt'] as dynamic).toDate(),
    );
  }

  static TripStatus _parseStatus(String status) {
    switch (status) {
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      default:
        return TripStatus.active;
    }
  }
}

class TrackPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory TrackPoint.fromMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return TrackPoint(
        latitude: (data['latitude'] ?? 0.0).toDouble(),
        longitude: (data['longitude'] ?? 0.0).toDouble(),
        timestamp: data['timestamp'] != null
            ? (data['timestamp'] as dynamic).toDate()
            : DateTime.now(),
      );
    }
    return TrackPoint(
      latitude: 0,
      longitude: 0,
      timestamp: DateTime.now(),
    );
  }

  Map<String, double> toLocation() {
    return {'latitude': latitude, 'longitude': longitude};
  }
}
