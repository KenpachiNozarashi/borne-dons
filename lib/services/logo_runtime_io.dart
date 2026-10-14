import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

Future<void> startLocalLogoService() async {
  if (!Platform.isWindows && !Platform.isLinux) return;
  final client = http.Client();
  try {
    try {
      final health = await client.get(Uri.parse('http://127.0.0.1:3002/health'))
          .timeout(const Duration(seconds: 2));
      if (health.statusCode == 200) return;
    } catch (_) {}
    final root = p.dirname(Platform.resolvedExecutable);
    final name = Platform.isWindows ? 'logo-service.exe' : 'logo-service';
    for (final location in [root, p.dirname(root)]) {
      final executable = p.join(location, 'logo-service', name);
      if (await File(executable).exists()) {
        await Process.start(executable, [],
          workingDirectory: p.dirname(executable), mode: ProcessStartMode.detached);
        return;
      }
    }
  } catch (_) {
    // The app remains usable when the optional logo service is unavailable.
  } finally {
    client.close();
  }
}
