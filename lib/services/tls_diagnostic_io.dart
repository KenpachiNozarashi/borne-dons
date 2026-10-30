import 'dart:io';
import 'package:rhttp/rhttp.dart' as native;
import 'windows_sumup_client.dart';

/// Explicit, credential-free probe of the actual DLL shipped with the app.
/// The negative probe requires tool/tls_fixture.py on the CI machine.
Future<void> runTlsDiagnostic() async {
  final report = <String>[];
  var passed = false;
  final client = WindowsSumupClient();
  native.RhttpClient? negative;
  try {
    if (!Platform.isWindows) throw StateError('Windows requis.');
    final response = await client.get(Uri.parse('https://api.sumup.com/'));
    if (response.statusCode < 100 || response.statusCode >= 500) {
      throw StateError('Réponse HTTP inattendue.');
    }
    report.add(
      'PASS: SumUp HTTPS validated by Windows (HTTP ${response.statusCode}). No credentials sent.',
    );
    negative = await native.RhttpClient.create(
      settings: WindowsSumupClient.settings,
    );
    try {
      await negative.get('https://localhost:18443/');
      throw StateError('Untrusted certificate was accepted.');
    } on native.RhttpInvalidCertificateException {
      report.add('PASS: untrusted localhost certificate rejected.');
    }
    passed = true;
  } catch (e) {
    // Only exception type, never raw requests, credentials, or response bodies.
    report.add(
      'FAIL: ${e.runtimeType}. Native TLS verification not confirmed.',
    );
  } finally {
    client.close();
    negative?.dispose(cancelRunningRequests: true);
    await File('tls-diagnostic.txt').writeAsString('${report.join('\n')}\n');
  }
  exit(passed ? 0 : 1);
}
