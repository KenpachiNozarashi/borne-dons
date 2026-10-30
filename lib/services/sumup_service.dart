import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'storage_service.dart';
import 'sumup_http_client.dart';

class SumupSetupException implements Exception {
  final String message;
  const SumupSetupException(this.message);
  @override
  String toString() => message;
}

class SumupService {
  final http.Client _client;
  final Duration requestTimeout;
  final Duration pairingTimeout;
  final Duration pollingInterval;
  final Duration paymentWindow;
  final Duration activationWait;
  final Duration cancellationWait;
  final Duration authorizationWait;
  bool _busy = false;
  String? _cancelReason;
  Duration? _cancelAt;
  final Stopwatch _clock;

  SumupService({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 4),
    this.pairingTimeout = const Duration(seconds: 15),
    this.pollingInterval = const Duration(seconds: 2),
    this.paymentWindow = const Duration(seconds: 90),
    this.activationWait = const Duration(seconds: 60),
    this.cancellationWait = const Duration(seconds: 15),
    this.authorizationWait = const Duration(seconds: 30),
    Stopwatch? clock,
  }) : _client = client ?? createSumupHttpClient(),
       _clock = clock ?? Stopwatch();

  Future<String?> pairSumupSolo(
    String merchantCode,
    String apiKey,
    String pairingCode,
  ) async {
    final url = Uri.parse('${AppConstants.sumupBaseUrl}/$merchantCode/readers');

    try {
      final response = await _request(
        'POST',
        url,
        apiKey,
        timeout: pairingTimeout,
        body: {'pairing_code': pairingCode, 'name': 'Borne de dons'},
      );
      if (response.statusCode != 201) {
        final message = switch (response.statusCode) {
          401 => 'Clé API SumUp refusée. Vérifiez la clé et le compte utilisé.',
          403 =>
            'Accès SumUp refusé. Vérifiez les droits de la clé et le compte marchand.',
          400 || 404 || 409 || 422 =>
            'Association du terminal refusée. Vérifiez le compte marchand et générez un nouveau code de jumelage sur le Solo.',
          429 => 'Trop de tentatives. Patientez avant de réessayer.',
          _ =>
            'SumUp est indisponible (HTTP ${response.statusCode}). Réessayez plus tard.',
        };
        throw SumupSetupException(message);
      }
      final data = jsonDecode(response.body);
      final id = data is Map ? data['id'] : null;
      if (id is! String || id.trim().isEmpty) {
        throw const SumupSetupException(
          'Réponse SumUp incomplète : identifiant du terminal absent.',
        );
      }
      return id;
    } on SumupSetupException {
      rethrow;
    } on TimeoutException {
      throw const SumupSetupException(
        'SumUp ne répond pas après 15 secondes. L’association peut avoir été reçue : vérifiez le Solo avant de générer un nouveau code.',
      );
    } on http.ClientException catch (e) {
      final tls = e.message.toLowerCase();
      throw SumupSetupException(
        tls.contains('certificat') || tls.contains('certificate')
            ? 'Connexion sécurisée à SumUp refusée. Vérifiez la date et les certificats Windows, ou transmettez le diagnostic au responsable.'
            : 'Connexion à SumUp impossible. Vérifiez Internet et réessayez.',
      );
    } catch (_) {
      throw const SumupSetupException(
        'Impossible de terminer l’association SumUp. Vérifiez la connexion et le terminal.',
      );
    }
  }

  static Map<String, dynamic> unknown() => {
    'success': false,
    'status': 'unknown',
    'error':
        'Le résultat du paiement n’a pas pu être confirmé. Vérifiez auprès du responsable avant de réessayer.',
  };

  Future<void> requestCancellation() async {
    if (!_busy || _cancelReason != null) return;
    _cancelReason = 'user';
    _cancelAt = _clock.elapsed;
  }

  String _operationId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _log(
    StorageService storage,
    String event,
    Map<String, dynamic> payment,
  ) async {
    try {
      await storage.logSumupPayment(event, payment['operation_id'] as String?);
    } catch (_) {}
  }

  // Abort timed-out HTTP requests as well as bounding the Future. In particular,
  // never leave a terminate request retrying after the payment window has closed.
  Future<http.Response> _request(
    String method,
    Uri uri,
    String key, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      method,
      uri,
      abortTrigger: abort.future,
    );
    request.headers['Authorization'] = 'Bearer $key';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      return await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            timeout ?? requestTimeout,
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('SumUp request timeout');
            },
          );
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<Map<String, dynamic>> startSoloCheckout({
    required double amount,
    required StorageService storage,
    void Function(String message)? onStatusUpdate,
  }) async {
    if (_busy)
      return {
        'success': false,
        'status': 'not_started',
        'error': 'Un paiement est déjà en cours.',
      };
    _busy = true;
    _cancelReason = null;
    _cancelAt = null;
    _clock
      ..reset()
      ..start();
    Map<String, dynamic>? payment;
    bool sent = false;
    try {
      final reader = await storage.getSumupReaderId();
      final merchant = await storage.getSumupMerchantCode();
      final key = await storage.getSumupApiKey();
      final appId = await storage.getSumupAppId();
      final afKey = await storage.getSumupAfKey();
      if (!amount.isFinite ||
          amount <= 0 ||
          [
            reader,
            merchant,
            key,
            appId,
            afKey,
          ].any((v) => v == null || v.isEmpty)) {
        return {
          'success': false,
          'status': 'not_started',
          'error': 'Configuration du terminal incomplète ou montant invalide.',
        };
      }
      payment = {
        'operation_id': _operationId(),
        'reader_id': reader,
        'merchant_code': merchant,
        'amount_minor': (amount * 100).round(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (_cancelReason != null)
        return {
          'success': false,
          'status': 'cancelled',
          'error': 'Demande annulée avant son envoi au terminal.',
        };
      await _log(storage, 'checkout_requested', payment);
      onStatusUpdate?.call('Initialisation du paiement…');
      sent = true;
      final response = await _request(
        'POST',
        Uri.parse(
          '${AppConstants.sumupBaseUrl}/$merchant/readers/$reader/checkout',
        ),
        key!,
        body: {
          'total_amount': {
            'minor_unit': 2,
            'currency': 'EUR',
            'value': payment['amount_minor'],
          },
          'affiliate': {
            'app_id': appId,
            'key': afKey,
            'foreign_transaction_id': payment['operation_id'],
          },
          'description': 'Donation Kiosk',
        },
      );
      if ([400, 401, 403, 404, 422].contains(response.statusCode)) {
        await _log(
          storage,
          'checkout_rejected_${response.statusCode}',
          payment,
        );
        return {
          'success': false,
          'status': 'not_started',
          'error': 'Le terminal n’a pas accepté la demande de paiement.',
        };
      }
      if (response.statusCode != 201) {
        await _log(
          storage,
          'checkout_response_${response.statusCode}',
          payment,
        );
        return unknown();
      }
      final data = jsonDecode(response.body)['data'] as Map;
      payment['checkout_id'] = data['checkout_id'];
      payment['client_transaction_id'] = data['client_transaction_id'];
      await _log(storage, 'checkout_accepted', payment);
      final acceptedAt = _clock.elapsed;
      Duration? readyAt;
      bool terminateAttempted = false;
      bool terminateAccepted = false;
      Map<String, dynamic> describe(Map<String, dynamic> result) {
        if (_cancelReason != null &&
            result['success'] != true &&
            (result['status'] == 'cancelled' ||
                (terminateAccepted && result['status'] == 'failed'))) {
          result['status'] = _cancelReason == 'timeout'
              ? 'timed_out'
              : 'cancelled';
          result['error'] = _cancelReason == 'timeout'
              ? 'Délai de paiement dépassé. Le paiement n’a pas abouti.'
              : 'Le paiement a été annulé.';
        }
        return result;
      }

      do {
        final result = await _readOutcome(storage, payment, key);
        if (result != null) return describe(result);
        final state = await _readerState(storage, payment, key);
        const waitingStates = [
          'WAITING_FOR_CARD',
          'WAITING_FOR_PIN',
          'WAITING_FOR_SIGNATURE',
          'SELECTING_TIP',
        ];
        final waiting = waitingStates.contains(state);
        if (waiting && readyAt == null) {
          readyAt = _clock.elapsed;
          await _log(storage, 'reader_ready_payment_window_started', payment);
        }
        if (_cancelReason == null &&
            readyAt != null &&
            _clock.elapsed - readyAt >= paymentWindow) {
          _cancelReason = 'timeout';
          _cancelAt = _clock.elapsed;
          await _log(storage, 'payment_deadline_reached', payment);
        }
        if (_cancelReason != null) {
          onStatusUpdate?.call(
            !waiting && !terminateAttempted
                ? 'Le paiement est en cours de traitement. Attente du résultat…'
                : _cancelReason == 'timeout'
                ? 'Délai dépassé. Annulation en cours…'
                : 'Annulation en cours…',
          );
          if (waiting && !terminateAttempted) {
            // Reconcile immediately before a reader-wide terminate command.
            final finalCheck = await _readOutcome(storage, payment, key);
            if (finalCheck != null) return describe(finalCheck);
            terminateAttempted = true;
            try {
              final stopped = await _request(
                'POST',
                Uri.parse(
                  '${AppConstants.sumupBaseUrl}/$merchant/readers/$reader/terminate',
                ),
                key,
              );
              terminateAccepted =
                  stopped.statusCode >= 200 && stopped.statusCode < 300;
              await _log(
                storage,
                'terminate_http_${stopped.statusCode}',
                payment,
              );
            } catch (_) {
              await _log(storage, 'terminate_response_unknown', payment);
            }
          }
          // Never try to force termination while the bank is processing or the
          // reader state cannot be established. A final outcome still wins.
          final limit = waiting || terminateAttempted
              ? cancellationWait
              : authorizationWait;
          if (_clock.elapsed - (_cancelAt ?? _clock.elapsed) >= limit) break;
        } else if (readyAt == null &&
            _clock.elapsed - acceptedAt >= activationWait) {
          onStatusUpdate?.call(
            'Le terminal n’a pas confirmé qu’il était prêt.',
          );
          break;
        } else {
          onStatusUpdate?.call(
            waiting
                ? 'Présentez votre carte ou suivez les instructions du terminal.'
                : 'Traitement du paiement en cours…',
          );
        }
        await Future<void>.delayed(pollingInterval);
      } while (true);
      final last = await _readOutcome(storage, payment, key);
      if (last != null) return describe(last);
      await _log(storage, 'result_unconfirmed', payment);
      return unknown();
    } catch (_) {
      if (payment != null)
        await _log(storage, 'request_or_network_uncertain', payment);
      return sent
          ? unknown()
          : {
              'success': false,
              'status': 'not_started',
              'error': 'Impossible de préparer le paiement.',
            };
    } finally {
      _busy = false;
      _clock.stop();
    }
  }

  Future<Map<String, dynamic>?> _getJson(
    Uri uri,
    String key,
    StorageService storage,
    Map<String, dynamic> payment,
  ) async {
    try {
      final response = await _request('GET', uri, key);
      if (response.statusCode != 200) {
        await _log(storage, 'status_http_${response.statusCode}', payment);
        return null;
      }
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      await _log(storage, 'status_unavailable', payment);
      return null;
    }
  }

  Future<String?> _readerState(
    StorageService storage,
    Map<String, dynamic> payment,
    String key,
  ) async {
    final response = await _getJson(
      Uri.parse(
        '${AppConstants.sumupBaseUrl}/${payment['merchant_code']}/readers/${payment['reader_id']}/status',
      ),
      key,
      storage,
      payment,
    );
    final data = response?['data'];
    if (data is! Map || data['status'] != 'ONLINE') return null;
    // This endpoint reports the last known screen: stale snapshots do not start
    // the timer or authorize termination of a potentially processing payment.
    final activity = DateTime.tryParse(data['last_activity']?.toString() ?? '');
    final created = DateTime.parse(payment['created_at'] as String);
    if (activity == null ||
        activity.isBefore(created.subtract(const Duration(seconds: 5))))
      return null;
    return data['state'] as String?;
  }

  Future<Map<String, dynamic>?> _readOutcome(
    StorageService storage,
    Map<String, dynamic> payment,
    String key,
  ) async {
    final merchant = payment['merchant_code'];
    final reader = payment['reader_id'];
    Map<String, dynamic>? checkout;
    if (payment['checkout_id'] is String) {
      final response = await _getJson(
        Uri.parse(
          '${AppConstants.sumupBaseUrl}/$merchant/readers/$reader/checkout/${payment['checkout_id']}',
        ),
        key,
        storage,
        payment,
      );
      if (response?['data'] is Map)
        checkout = Map<String, dynamic>.from(response!['data']);
    }
    final transaction = await _getJson(
      Uri.https(
        'api.sumup.com',
        '/v2.1/merchants/$merchant/transactions',
        payment['client_transaction_id'] is String
            ? {
                'client_transaction_id':
                    payment['client_transaction_id'] as String,
              }
            : {'foreign_transaction_id': payment['operation_id'] as String},
      ),
      key,
      storage,
      payment,
    );
    final txStatus = (transaction?['status'] as String?)?.toLowerCase();
    final checkoutStatus = (checkout?['status'] as String?)?.toLowerCase();
    // A terminal checkout has its own final status. A financial PENDING
    // snapshot must not hide an already confirmed reader cancellation.
    // A final financial result (in particular success) still takes precedence.
    const finalStatuses = ['successful', 'failed', 'cancelled', 'refunded'];
    final status = finalStatuses.contains(txStatus) ? txStatus : checkoutStatus;
    if (!finalStatuses.contains(status)) return null;
    final messages = {
      'successful': 'Votre paiement a bien été validé.',
      'failed': 'Le paiement a échoué ou a été refusé.',
      'cancelled': 'Le paiement a été annulé.',
      'refunded': 'Ce paiement a été remboursé.',
    };
    await _log(storage, 'result_$status', payment);
    return {
      'success': status == 'successful',
      'payment_confirmed': status == 'successful',
      'status': status,
      'transaction_id': transaction?['id'],
      'amount': (payment['amount_minor'] as num) / 100,
      'message': messages[status],
      'error': messages[status],
    };
  }
}
