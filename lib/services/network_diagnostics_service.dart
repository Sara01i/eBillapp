import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

enum NetworkProbeStatus {
  online,
  timeout,
  offline,
  dnsFailure,
  unreachable,
  unknown,
}

class NetworkProbeResult {
  const NetworkProbeResult({
    required this.status,
    required this.message,
  });

  final NetworkProbeStatus status;
  final String message;

  bool get isOnline => status == NetworkProbeStatus.online;
}

class NetworkDiagnosticsService {
  static const Duration _dnsTimeout = Duration(seconds: 4);
  static const Duration _httpTimeout = Duration(seconds: 6);
  static const String _dnsHost = 'firebase.google.com';
  static final Uri _probeUri = Uri.parse('https://www.google.com/generate_204');

  static Future<NetworkProbeResult> runProbe() async {
    final NetworkProbeResult dnsResult = await _runDnsProbe();
    if (!dnsResult.isOnline) {
      return dnsResult;
    }

    return _runHttpProbe();
  }

  static Future<NetworkProbeResult> _runDnsProbe() async {
    try {
      final List<InternetAddress> addresses =
          await InternetAddress.lookup(_dnsHost).timeout(_dnsTimeout);
      if (addresses.isEmpty) {
        return const NetworkProbeResult(
          status: NetworkProbeStatus.dnsFailure,
          message:
              'تعذر الوصول لخدمات Firebase (DNS). تحقق من اتصال المحاكي بالإنترنت.',
        );
      }

      return const NetworkProbeResult(
        status: NetworkProbeStatus.online,
        message: 'DNS lookup successful.',
      );
    } on TimeoutException catch (error, stackTrace) {
      developer.log(
        'DNS probe timeout',
        name: 'NetworkDiagnosticsService',
        error: error,
        stackTrace: stackTrace,
      );
      return const NetworkProbeResult(
        status: NetworkProbeStatus.timeout,
        message:
            'اتصال الشبكة بطيء جداً (انتهت مهلة DNS). أعد المحاولة بعد التأكد من الإنترنت.',
      );
    } on SocketException catch (error, stackTrace) {
      developer.log(
        'DNS probe socket error',
        name: 'NetworkDiagnosticsService',
        error: error,
        stackTrace: stackTrace,
      );
      return const NetworkProbeResult(
        status: NetworkProbeStatus.offline,
        message: 'لا يوجد اتصال إنترنت على الجهاز/المحاكي حالياً.',
      );
    } catch (error, stackTrace) {
      developer.log(
        'DNS probe unknown error',
        name: 'NetworkDiagnosticsService',
        error: error,
        stackTrace: stackTrace,
      );
      return const NetworkProbeResult(
        status: NetworkProbeStatus.unknown,
        message: 'تعذر التحقق من اتصال الشبكة حالياً.',
      );
    }
  }

  static Future<NetworkProbeResult> _runHttpProbe() async {
    final HttpClient client = HttpClient()..connectionTimeout = _httpTimeout;
    try {
      final HttpClientRequest request =
          await client.getUrl(_probeUri).timeout(_httpTimeout);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

      final HttpClientResponse response =
          await request.close().timeout(_httpTimeout);
      final int statusCode = response.statusCode;
      await response.drain();

      if (statusCode >= 200 && statusCode < 500) {
        return const NetworkProbeResult(
          status: NetworkProbeStatus.online,
          message: 'Network probe successful.',
        );
      }

      return NetworkProbeResult(
        status: NetworkProbeStatus.unreachable,
        message:
            'الشبكة متاحة لكن الاستجابة من الخادم غير مستقرة (status: $statusCode).',
      );
    } on TimeoutException catch (error, stackTrace) {
      developer.log(
        'HTTP probe timeout',
        name: 'NetworkDiagnosticsService',
        error: error,
        stackTrace: stackTrace,
      );
      return const NetworkProbeResult(
        status: NetworkProbeStatus.timeout,
        message: 'انتهت مهلة الاتصال. تحقق من الإنترنت ثم أعد المحاولة.',
      );
    } on SocketException catch (error, stackTrace) {
      developer.log(
        'HTTP probe socket error',
        name: 'NetworkDiagnosticsService',
        error: error,
        stackTrace: stackTrace,
      );
      return const NetworkProbeResult(
        status: NetworkProbeStatus.offline,
        message: 'لا يوجد اتصال إنترنت مستقر حالياً.',
      );
    } on HandshakeException catch (error, stackTrace) {
      developer.log(
        'HTTP probe handshake error',
        name: 'NetworkDiagnosticsService',
        error: error,
        stackTrace: stackTrace,
      );
      return const NetworkProbeResult(
        status: NetworkProbeStatus.unreachable,
        message:
            'فشل الاتصال الآمن (TLS). تحقق من وقت وتاريخ المحاكي ومن خدمات Google.',
      );
    } on HttpException catch (error, stackTrace) {
      developer.log(
        'HTTP probe interrupted',
        name: 'NetworkDiagnosticsService',
        error: error,
        stackTrace: stackTrace,
      );
      return const NetworkProbeResult(
        status: NetworkProbeStatus.unreachable,
        message: 'تم قطع الاتصال بالشبكة أثناء الطلب. حاول مرة أخرى.',
      );
    } catch (error, stackTrace) {
      developer.log(
        'HTTP probe unknown error',
        name: 'NetworkDiagnosticsService',
        error: error,
        stackTrace: stackTrace,
      );
      return const NetworkProbeResult(
        status: NetworkProbeStatus.unknown,
        message: 'تعذر تشخيص الشبكة حالياً. حاول مجدداً بعد لحظات.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
