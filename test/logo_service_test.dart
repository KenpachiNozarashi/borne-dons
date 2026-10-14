import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:borne_dons/services/logo_service.dart';

void main() {
  test('Logo is sent only to local service and PNG returned', () async {
    final service = LogoService(client: MockClient((request) async {
      if (request.url.path == '/health') return http.Response('{\"status\":\"ready\"}', 200);
      expect(request.url.host, '127.0.0.1');
      expect(request.url.port, 3002);
      expect(request.bodyBytes, [1, 2, 3]);
      return http.Response.bytes([4, 5, 6], 200, headers: {'content-type': 'image/png'});
    }));
    expect(await service.removeBackground(Uint8List.fromList([1, 2, 3])), [4, 5, 6]);
    service.dispose();
  });
  test('Failed removal is reported to caller instead of saved as image', () async {
    final service = LogoService(client: MockClient((request) async => http.Response('{}', request.url.path == '/health' ? 200 : 422)));
    await expectLater(service.removeBackground(Uint8List.fromList([1])), throwsException);
    service.dispose();
  });
}
