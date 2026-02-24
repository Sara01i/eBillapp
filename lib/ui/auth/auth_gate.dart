import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../home/home_screen.dart';
import '../widgets/app_scaffold.dart';
import 'login_screen.dart';
import 'verify_email_otp_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  bool _syncInProgress = false;
  String? _lastSyncUid;

  void _syncUserInBackground(User user) {
    if (_syncInProgress || _lastSyncUid == user.uid) {
      return;
    }

    _syncInProgress = true;
    _lastSyncUid = user.uid;

    _refreshUserAndProfile(user).whenComplete(() {
      _syncInProgress = false;
    });
  }

  Future<void> _refreshUserAndProfile(User user) async {
    try {
      await user.reload().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Routing must continue even if user reload fails.
    }

    try {
      await _authService
          .ensureCurrentUserDocument()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Do not block gate on Firestore self-heal.
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.userChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting &&
            !authSnapshot.hasData) {
          return const _GateLoadingView();
        }

        final User? streamUser = authSnapshot.data;
        if (streamUser == null) {
          _lastSyncUid = null;
          return const LoginScreen();
        }

        _syncUserInBackground(streamUser);

        final User effectiveUser = _auth.currentUser ?? streamUser;

        // PHASE 2: Live monitoring of user status in Firestore
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection(AuthService.usersCollection)
              .doc(effectiveUser.uid)
              .snapshots(),
          builder: (context, userDocSnapshot) {
            if (userDocSnapshot.connectionState == ConnectionState.waiting &&
                !userDocSnapshot.hasData) {
              return const _GateLoadingView();
            }

            final data = userDocSnapshot.data?.data();

            // If document doesn't exist yet, show verification (safety measure)
            if (data == null) {
              return VerifyEmailOtpScreen(email: effectiveUser.email ?? '');
            }

            final bool emailOtpVerified = data['emailOtpVerified'] == true;

            // Security Block: Force verification if not verified in Firestore
            if (!emailOtpVerified) {
              final String emailFromDoc = (data['email'] as String? ?? '').trim();
              final String email = emailFromDoc.isNotEmpty
                  ? emailFromDoc
                  : (effectiveUser.email ?? '');
              return VerifyEmailOtpScreen(email: email);
            }

            // Grant Access
            return const HomeScreen();
          },
        );
      },
    );
  }
}

class _GateLoadingView extends StatelessWidget {
  const _GateLoadingView();

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'جاري التحقق',
      subtitle: 'يتم تجهيز جلسة المستخدم...',
      child: Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );
  }
}
