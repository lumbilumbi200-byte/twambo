class User {
  final int id;
  final String phoneNumber;
  final String fullName;
  final String role;
  final String? profilePhoto;
  final int strikeCount;
  final bool isBanned;
  final String? driverVerificationStatus; // 'pending' | 'approved' | 'rejected' | 'suspended'

  const User({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    this.profilePhoto,
    required this.strikeCount,
    required this.isBanned,
    this.driverVerificationStatus,
  });

  bool get isDriver => role == 'driver';
  bool get isRider => role == 'rider';
  bool get isApprovedDriver => isDriver && driverVerificationStatus == 'approved';

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        phoneNumber: j['phone_number'],
        fullName: j['full_name'],
        role: j['role'],
        profilePhoto: j['profile_photo'],
        strikeCount: j['strike_count'] ?? 0,
        isBanned: j['is_banned'] ?? false,
        driverVerificationStatus: j['driver_verification_status'],
      );
}
