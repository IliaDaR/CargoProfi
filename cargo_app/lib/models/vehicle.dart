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
  final String? techExamNumber;
  final DateTime? techExamDate;
  final String? techExamPhotoUrl;
  final bool isActive;
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
    this.techExamNumber,
    this.techExamDate,
    this.techExamPhotoUrl,
  });

  factory Vehicle.fromMap(String id, Map<String, dynamic> data) {
    return Vehicle(
      id: id, ownerId: data['ownerId'] ?? '',
      plateNumber: data['plateNumber'] ?? '', brand: data['brand'] ?? '', model: data['model'] ?? '',
      year: data['year'], vin: data['vin'], fuelType: data['fuelType'],
      createdAt: data['createdAt'] != null ? (data['createdAt'] as dynamic).toDate() : DateTime.now(),
      techExamNumber: data['techExamNumber'],
      techExamDate: data['techExamDate'] != null ? DateTime.tryParse(data['techExamDate'] ?? '') : null,
      techExamPhotoUrl: data['techExamPhotoUrl'],
    );
  }

  Vehicle copyWith({
    bool? isActive, String? activeDriverId,
    String? techExamNumber, DateTime? techExamDate, String? techExamPhotoUrl,
  }) {
    return Vehicle(
      id: id, ownerId: ownerId, plateNumber: plateNumber, brand: brand, model: model,
      year: year, vin: vin, fuelType: fuelType, createdAt: createdAt,
      isActive: isActive ?? this.isActive,
      activeDriverId: activeDriverId ?? this.activeDriverId,
      techExamNumber: techExamNumber ?? this.techExamNumber,
      techExamDate: techExamDate ?? this.techExamDate,
      techExamPhotoUrl: techExamPhotoUrl ?? this.techExamPhotoUrl,
    );
  }

  String get displayName => '$brand $model ($plateNumber)';
}
