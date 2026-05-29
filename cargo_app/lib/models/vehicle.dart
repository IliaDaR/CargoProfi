class Vehicle {
  final String id;
  final String ownerId;
  final String plateNumber;
  final String brand;
  final String model;
  final int? year;
  final String? vin;
  final String? fuelType;
  final DateTime createdAt;

  // Локальные поля (не в Firestore)
  final bool isActive; // в рейсе или нет
  final String? activeDriverId;

  Vehicle({
    required this.id,
    required this.ownerId,
    required this.plateNumber,
    required this.brand,
    required this.model,
    this.year,
    this.vin,
    this.fuelType,
    required this.createdAt,
    this.isActive = false,
    this.activeDriverId,
  });

  factory Vehicle.fromMap(String id, Map<String, dynamic> data) {
    return Vehicle(
      id: id,
      ownerId: data['ownerId'] ?? '',
      plateNumber: data['plateNumber'] ?? '',
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      year: data['year'],
      vin: data['vin'],
      fuelType: data['fuelType'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Vehicle copyWith({
    bool? isActive,
    String? activeDriverId,
  }) {
    return Vehicle(
      id: id,
      ownerId: ownerId,
      plateNumber: plateNumber,
      brand: brand,
      model: model,
      year: year,
      vin: vin,
      fuelType: fuelType,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
      activeDriverId: activeDriverId ?? this.activeDriverId,
    );
  }

  String get displayName => '$brand $model ($plateNumber)';
}
