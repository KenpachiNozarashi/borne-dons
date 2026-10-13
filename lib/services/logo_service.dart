import 'dart:typed_data';
import 'package:http/http.dart' as http;

class LogoService {
  final http.Client _client;
  LogoService({http.Client? client}) : _client = client ?? http.Client();

  Future<Uint8List> removeBackground(Uint8List image) async {
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
