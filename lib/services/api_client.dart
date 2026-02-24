import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  /// Base URL is platform-aware:
  /// - Android emulator: http://10.0.2.2:3000
  /// - Windows / desktop / web: http://localhost:3000
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('ApiClient Error: User is null');
      }
      throw ApiException(
        code: 'UNAUTHENTICATED',
        message: 'جلسة الدخول غير صالحة، الرجاء تسجيل الدخول مرة أخرى.',
        status: 401,
      );
    }

    final String url = '$baseUrl$path';
    final String? token = await user.getIdToken(true);

    if (kDebugMode) {
      debugPrint('--> POST $url');
      debugPrint('Payload: ${jsonEncode(body)}');
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        debugPrint('<-- STATUS: ${response.statusCode}');
        debugPrint('Body: ${response.body}');
      }

      final decodedResponse = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decodedResponse;
      } else {
        throw ApiException(
          code: decodedResponse['code'] ?? 'SERVER_ERROR',
          message: decodedResponse['message'] ?? 'خطأ في الخادم',
          status: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ApiClient Request Failed: $e');
      rethrow;
    }
  }
}

class ApiException implements Exception {
  final String code;
  final String message;
  final int status;

  ApiException({required this.code, required this.message, required this.status});

  @override
  String toString() => message;
}
