import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        case 'UNAUTHENTICATED':
          return 'جلسة الدخول انتهت، سجل دخول مرة ثانية.';
        case 'FORBIDDEN':
          return 'لا يمكنك الإرسال الآن. انتظر قليلاً ثم أعد المحاولة.';
        case 'NOT_FOUND':
          return 'لا يوجد رمز نشط. اضغط إعادة إرسال.';
        case 'GONE':
          return 'انتهت صلاحية الرمز. أعد الإرسال.';
        case 'TOO_MANY_REQUESTS':
          return 'تجاوزت عدد المحاولات. انتظر ثم أعد المحاولة.';
        case 'BAD_REQUEST':
          return 'تأكد من إدخال الرمز بشكل صحيح.';
        default:
          return error.message;
      }
    }
    if (error is AuthOperationException) return error.message;
    return error.toString();
  }

  // ---------- AUTH ----------

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
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      await _firestore.collection(usersCollection).doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'name': name,
        'phoneNumber': phoneNumber,
        'emailOtpVerified': false,
        'loginOtpPending': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return user.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthOperationException(_handleAuthException(e));
    }
  }

  Future<void> signOut() async {
    await markLoginOtpPending(false).catchError((_) {});
    await _auth.signOut();
  }

  // ---------- OTP (Email) ----------

  Future<void> sendEmailOtpForEmail(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty) {
      throw const AuthOperationException('البريد الإلكتروني غير صحيح.');
    }
    await _apiClient.post('/v1/email-otp/send', {'email': normalized});
  }

  Future<void> sendEmailOtp() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthOperationException('يجب تسجيل الدخول أولاً');
    final email = (user.email ?? '').trim();
    if (email.isEmpty) throw const AuthOperationException('لا يوجد بريد للمستخدم.');
    await sendEmailOtpForEmail(email);
  }

  Future<void> verifyEmailOtp(String code) async {
    final c = code.trim();
    if (c.length < 4) {
      throw const AuthOperationException('الرمز غير صحيح.');
    }
    await _apiClient.post('/v1/email-otp/verify', {'code': c});
  }

  // ---------- Firestore helpers ----------

  Future<void> ensureCurrentUserDocument() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection(usersCollection).doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'uid': user.uid,
        'email': user.email,
        'emailOtpVerified': false,
        'loginOtpPending': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> markLoginOtpPending(bool value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection(usersCollection).doc(user.uid).set(
      {
        'loginOtpPending': value,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthOperationException(_handleAuthException(e));
    }
  }

  Future<void> deleteCurrentUserAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _firestore.collection(usersCollection).doc(user.uid).delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthOperationException('هذه العملية تتطلب تسجيل دخول حديث. يرجى الخروج والدخول مرة أخرى.');
      }
      throw AuthOperationException(_handleAuthException(e));
    }
  }

  String _handleAuthException(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'المستخدم غير موجود.';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة.';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح.';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة.';
      default:
        return error.message ?? 'فشلت العملية.';
    }
  }
}
