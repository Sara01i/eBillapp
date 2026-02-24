import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'network_diagnostics_service.dart';
import 'api_client.dart';

class AuthOperationException implements Exception {
  const AuthOperationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _apiClient = ApiClient();

  static const String usersCollection = 'users';
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final ApiClient _apiClient;

  Stream<User?> get userStream => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  String toUserMessage(Object error) {
    if (error is ApiException) {
      switch (error.code) {
        case 'UNAUTHENTICATED': return 'جلسة الدخول انتهت، سجل دخول مرة ثانية.';
        case 'FORBIDDEN': return 'لا يمكنك الإرسال الآن. انتظر قليلاً ثم أعد المحاولة.';
        case 'NOT_FOUND': return 'لا يوجد رمز نشط. اضغط إعادة إرسال.';
        case 'GONE': return 'انتهت صلاحية الرمز. أعد الإرسال.';
        case 'TOO_MANY_REQUESTS': return 'تجاوزت عدد المحاولات. انتظر ثم أعد المحاولة.';
        case 'BAD_REQUEST': return 'تأكد من إدخال الرمز بشكل صحيح.';
        default: return error.message;
      }
    }
    if (error is AuthOperationException) return error.message;
    return error.toString();
  }

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthOperationException(_handleAuthException(e));
    }
  }

  Future<String> register({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user!;

      await _firestore.collection(usersCollection).doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'name': name,
        'phoneNumber': phoneNumber,
        'emailOtpVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return user.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthOperationException(_handleAuthException(e));
    }
  }

  Future<void> sendEmailOtp() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthOperationException('يجب تسجيل الدخول أولاً');
    await _apiClient.post('/v1/email-otp/send', {'email': user.email});
  }

  Future<void> verifyEmailOtp(String code) async {
    await _apiClient.post('/v1/email-otp/verify', {'code': code});
  }

  Future<void> signOut() async => await _auth.signOut();

  // Stub implementations added for compilation only.
  Future<void> ensureCurrentUserDocument() async {}

  Future<void> sendPasswordReset(String email) async {}

  Future<void> deleteCurrentUserAccount() async {}

  String _handleAuthException(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found': return 'المستخدم غير موجود.';
      case 'wrong-password': return 'كلمة المرور غير صحيحة.';
      case 'email-already-in-use': return 'البريد الإلكتروني مستخدم بالفعل.';
      default: return error.message ?? 'فشلت العملية.';
    }
  }
}
