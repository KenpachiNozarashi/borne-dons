import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'logo_runtime.dart';

class LogoService {
  final http.Client _client;
  LogoService({http.Client? client}) : _client = client ?? http.Client();

  Future<Uint8List> removeBackground(Uint8List image) async {
    await startLocalLogoService();
    var ready = false;
    for (var attempt = 0; attempt < 45; attempt++) {
      try {
        final health = await _client.get(Uri.parse('http://127.0.0.1:3002/health'))
            .timeout(const Duration(seconds: 1));
        if (health.statusCode == 200) { ready = true; break; }
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!ready) throw Exception('Le service de détourage ne démarre pas. Consultez le journal logo-service.log.');
    final response = await _client.post(
      Uri.parse('http://127.0.0.1:3002/remove-background'),
      headers: {'Content-Type': 'application/octet-stream'},
      body: image,
    ).timeout(const Duration(seconds: 90));
    if (response.statusCode != 200 || !response.headers['content-type'].toString().startsWith('image/png')) {
      throw Exception('Le détourage local n’a pas abouti.');
    }
    return response.bodyBytes;
  }

  void dispose() => _client.close();
}
