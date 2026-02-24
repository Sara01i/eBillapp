import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

class UserProfileData {
  const UserProfileData({
    required this.uid,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.emailOtpVerified,
    required this.phoneVerified,
  });

  final String uid;
  final String name;
  final String email;
  final String phoneNumber;
  final bool emailOtpVerified;
  final bool phoneVerified;

  factory UserProfileData.fromMap({
    required String uid,
    required Map<String, dynamic> data,
    required String fallbackEmail,
  }) {
    return UserProfileData(
      uid: uid,
      name: (data['name'] as String? ?? '').trim(),
      email: (data['email'] as String? ?? fallbackEmail).trim(),
      phoneNumber: (data['phoneNumber'] as String? ?? '').trim(),
      emailOtpVerified: data['emailOtpVerified'] == true,
      phoneVerified: data['phoneVerified'] == true,
    );
  }
}

class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return _firestore.collection(AuthService.usersCollection).doc(uid);
  }

  Stream<UserProfileData> watchProfile({
    required String uid,
    required String fallbackEmail,
  }) {
    return _userRef(uid).snapshots().map((snapshot) {
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(snapshot.data() ?? const {});
      return UserProfileData.fromMap(
        uid: uid,
        data: data,
        fallbackEmail: fallbackEmail,
      );
    });
  }

  Future<UserProfileData> fetchProfile({
    required String uid,
    required String fallbackEmail,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _userRef(uid).get();
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(snapshot.data() ?? const {});
    return UserProfileData.fromMap(
      uid: uid,
      data: data,
      fallbackEmail: fallbackEmail,
    );
  }

  Future<bool> userExists(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _userRef(uid).get();
    return snapshot.exists;
  }

  Future<void> updateProfile({
    required String uid,
    required String name,
    String? phoneNumber,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final String normalizedPhone = (phoneNumber ?? '').trim();
    payload['phoneNumber'] = normalizedPhone;

    await _userRef(uid).set(payload, SetOptions(merge: true));
  }
}
