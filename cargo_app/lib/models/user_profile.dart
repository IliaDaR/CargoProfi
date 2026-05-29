import '../utils/constants.dart';

class UserProfile {
  final String uid;
  final UserRole role;
  final String displayName;
  final String email;
  final String? phone;
  final String? ownerId; // для driver
  final String? assignedVehicleId;
  final List<String> driverIds; // для owner
  final String? companyName;

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
    };
  }
}
