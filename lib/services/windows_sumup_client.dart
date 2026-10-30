import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:rhttp/rhttp.dart' as native;

/// Native Windows certificate-chain validation, including Windows' automatic
/// intermediate/root discovery. Never falls back to accepting a bad certificate.
class WindowsSumupClient extends http.BaseClient {
  static Future<void>? _initialization;
  Future<native.RhttpClient>? _client;
  bool _closed = false;
  final _pending = <Completer<void>>{};

  static const settings = native.ClientSettings(
    tlsSettings: native.TlsSettings(
      rootCertSource: native.RootCertSource.platform,
      verifyCertificates: true,
    ),
    redirectSettings: native.RedirectSettings.none(),
    timeoutSettings: native.TimeoutSettings(
      timeout: Duration(seconds: 20),
      connectTimeout: Duration(seconds: 10),
    ),
    throwOnStatusCode: false,
  );

  Future<native.RhttpClient> _open() async {
    try {
      await (_initialization ??= native.Rhttp.init());
    } catch (_) {
      _initialization = null;
      rethrow;
    }
    return native.RhttpClient.create(settings: settings);
  }

  Future<native.RhttpClient> _getClient() async {
    final opening = _client ??= _open();
    try {
      return await opening;
    } catch (_) {
      if (identical(_client, opening)) _client = null;
      rethrow;
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('Client fermé.', request.url);
    // No redirects or arbitrary endpoints may receive merchant credentials.
    if (request.url.scheme != 'https' ||
        request.url.host != 'api.sumup.com' ||
        request.url.port != 443 ||
        request.url.userInfo.isNotEmpty) {
      throw http.ClientException('Adresse SumUp non autorisée.');
    }
    final stopped = Completer<void>();
    _pending.add(stopped);
    var finished = false;
    var started = false;
    native.CancelToken? token;
    Future<void> stop() async {
      if (finished || stopped.isCompleted) return;
      stopped.complete();
      if (started && token != null) await token.cancel();
    }

    if (request is http.Abortable) {
      request.abortTrigger?.then((_) => unawaited(stop()));
    }
    // close() also aborts requests, including ones waiting for initialization.
    Future<T> beforeStop<T>(Future<T> action) => Future.any([
      action,
      stopped.future.then<T>(
        (_) => throw http.RequestAbortedException(request.url),
      ),
    ]);
    try {
      final body = await beforeStop(request.finalize().toBytes());
      final client = await beforeStop(_getClient());
      if (stopped.isCompleted || _closed) {
        throw http.RequestAbortedException(request.url);
      }
      token = native.CancelToken();
      started = true;
      final response = await beforeStop(
        client.requestBytes(
          method: native.HttpMethod(request.method),
          url: request.url.toString(),
          headers: native.HttpHeaders.rawMap(request.headers),
          body: body.isEmpty
              ? null
              : native.HttpBody.bytes(Uint8List.fromList(body)),
          cancelToken: token,
        ),
      );
      return http.StreamedResponse(
        Stream.value(response.body),
        response.statusCode,
        request: request,
        contentLength: response.body.length,
        headers: response.headerMap,
      );
    } on native.RhttpCancelException {
      throw http.RequestAbortedException(request.url);
    } on native.RhttpInvalidCertificateException {
      throw http.ClientException(
        'Connexion sécurisée refusée : certificat non reconnu.',
      );
    } on native.RhttpTimeoutException {
      throw TimeoutException('Le serveur SumUp ne répond pas.');
    } on native.RhttpException {
      // Native errors can contain request details: never expose them or the keys.
      throw http.ClientException('Connexion à SumUp impossible.');
    } finally {
      finished = true;
      _pending.remove(stopped);
      if (started && token != null) {
        unawaited(token.cancel().catchError((Object _) {}));
      }
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final stop in _pending) {
      if (!stop.isCompleted) stop.complete();
    }
    _client?.then(
      (client) => client.dispose(cancelRunningRequests: true),
      onError: (Object _) {},
    );
    super.close();
  }
}
