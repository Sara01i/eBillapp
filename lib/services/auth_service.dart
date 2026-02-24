import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        _firestore = firestore ?? FirebaseFirestore.instance;

  static const String usersCollection = 'users';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get userStream => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  String toUserMessage(Object error) {
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
        'emailOtpVerified': true, // Auto-verify
        'loginOtpPending': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return user.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthOperationException(_handleAuthException(e));
    }
  }

  Future<void> signOut() async => _auth.signOut();

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
        'emailOtpVerified': true,
        'loginOtpPending': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
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
