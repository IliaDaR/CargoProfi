import '../utils/constants.dart';

class UserProfile {
  final String uid;
  final UserRole role;
  final String displayName;
  final String email;
  final String? phone;
  final String? ownerId;
  final String? assignedVehicleId;
  final List<String> driverIds;
  final String? companyName;
  final String? licenseNumber;
  final String? medExamNumber;
  final DateTime? medExamDate;
  final String? medExamPhotoUrl;

  UserProfile({
    required this.uid,
    required this.role,
    required this.displayName,
    required this.email,
    this.phone,
    this.ownerId,
    this.assignedVehicleId,
    this.driverIds = const [],
    this.companyName,
    this.licenseNumber,
    this.medExamNumber,
    this.medExamDate,
    this.medExamPhotoUrl,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      role: data['role'] == 'owner' ? UserRole.owner : UserRole.driver,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      ownerId: data['ownerId'],
      assignedVehicleId: data['assignedVehicleId'],
      driverIds: List<String>.from(data['driverIds'] ?? []),
      companyName: data['companyName'],
      licenseNumber: data['licenseNumber'],
      medExamNumber: data['medExamNumber'],
      medExamDate: data['medExamDate'] != null ? DateTime.tryParse(data['medExamDate']) : null,
      medExamPhotoUrl: data['medExamPhotoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role == UserRole.owner ? 'owner' : 'driver',
      'displayName': displayName,
      'email': email,
      if (phone != null) 'phone': phone,
      if (ownerId != null) 'ownerId': ownerId,
      if (assignedVehicleId != null) 'assignedVehicleId': assignedVehicleId,
      if (driverIds.isNotEmpty) 'driverIds': driverIds,
      if (companyName != null) 'companyName': companyName,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
      if (medExamNumber != null) 'medExamNumber': medExamNumber,
      if (medExamDate != null) 'medExamDate': medExamDate!.toIso8601String(),
      if (medExamPhotoUrl != null) 'medExamPhotoUrl': medExamPhotoUrl,
    };
  }
}
