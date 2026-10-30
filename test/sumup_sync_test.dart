import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:borne_dons/services/storage_service.dart';
import 'package:borne_dons/services/sumup_service.dart';
import 'package:borne_dons/features/payment/payment_screen.dart';
import 'package:borne_dons/features/payment/widgets/payment_dialog.dart';

const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
http.Response jsonResponse(Object value, [int code = 200]) =>
    http.Response(jsonEncode(value), code);
http.Response accepted() => jsonResponse({
  'data': {
    'checkout_id': 'checkout-test',
    'client_transaction_id': 'client-test',
  },
}, 201);
http.Response readerState([
  String state = 'WAITING_FOR_CARD',
  bool online = true,
]) => jsonResponse({
  'data': {
    'state': state,
    'status': online ? 'ONLINE' : 'OFFLINE',
    'last_activity': DateTime.now().toUtc().toIso8601String(),
  },
});
SumupService service(
  Future<http.Response> Function(http.Request) handle, {
  Duration window = Duration.zero,
  Duration activation = Duration.zero,
  Duration cancellation = Duration.zero,
  Duration authorization = Duration.zero,
}) => SumupService(
  client: MockClient(handle),
  paymentWindow: window,
  activationWait: activation,
  cancellationWait: cancellation,
  authorizationWait: authorization,
  pollingInterval: Duration.zero,
  requestTimeout: const Duration(milliseconds: 50),
);

class TestClock implements Stopwatch {
  Duration time = Duration.zero;
  bool running = false;
  @override
  Duration get elapsed => time;
  @override
  int get elapsedMilliseconds => time.inMilliseconds;
  @override
  int get elapsedMicroseconds => time.inMicroseconds;
  @override
  int get elapsedTicks => time.inMicroseconds;
  @override
  int get frequency => 1000000;
  @override
  bool get isRunning => running;
  @override
  void start() => running = true;
  @override
  void stop() => running = false;
  @override
  void reset() => time = Duration.zero;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'read') return 'fixture-${call.arguments['key']}';
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'Ninety seconds are measured from readiness, not the initial request',
    () async {
      final storage = await StorageService.initialize();
      final clock = TestClock();
      int states = 0, stops = 0;
      final api = SumupService(
        clock: clock,
        pollingInterval: Duration.zero,
        client: MockClient((r) async {
          if (r.method == 'POST' && r.url.path.endsWith('/checkout'))
            return accepted();
          if (r.url.path.endsWith('/terminate')) {
            expect(states, 4);
            expect(clock.elapsed, const Duration(seconds: 120));
            stops++;
            return http.Response('', 204);
          }
          if (r.url.path.endsWith('/status')) {
            states++;
            clock.time = Duration(
              seconds: states <= 2
                  ? 30
                  : states == 3
                  ? 119
                  : 120,
            );
            return readerState(states == 1 ? 'IDLE' : 'WAITING_FOR_CARD');
          }
          if (r.url.path.contains('/checkout/'))
            return jsonResponse({
              'data': {'status': stops > 0 ? 'cancelled' : 'pending'},
            });
          return jsonResponse({}, 404);
        }),
      );
      final result = await api.startSoloCheckout(amount: 5, storage: storage);
      expect(stops, 1);
      expect(result['status'], 'timed_out');
    },
  );
  test(
    'Automatic deadline does not terminate a payment already processing at the bank',
    () async {
      final storage = await StorageService.initialize();
      final clock = TestClock();
      int states = 0;
      final api = SumupService(
        clock: clock,
        pollingInterval: Duration.zero,
        client: MockClient((r) async {
          if (r.method == 'POST') {
            expect(r.url.path, endsWith('/checkout'));
            return accepted();
          }
          if (r.url.path.endsWith('/status')) {
            states++;
            clock.time = states > 1
                ? const Duration(seconds: 90)
                : Duration.zero;
            return readerState(states == 1 ? 'WAITING_FOR_CARD' : 'IDLE');
          }
          if (r.url.path.contains('/checkout/'))
            return jsonResponse({
              'data': {'status': 'pending'},
            });
          return states >= 2
              ? jsonResponse({'status': 'SUCCESSFUL', 'id': 'approved'})
              : jsonResponse({}, 404);
        }),
      );
      expect(
        (await api.startSoloCheckout(amount: 5, storage: storage))['success'],
        true,
      );
    },
  );
  test(
    'Confirmed reader cancellation is not hidden by a lagging pending transaction',
    () async {
      final storage = await StorageService.initialize();
      final api = service((r) async {
        if (r.method == 'POST') {
          expect(r.url.path, endsWith('/checkout'));
          return accepted();
        }
        if (r.url.path.contains('/checkout/'))
          return jsonResponse({
            'data': {'status': 'cancelled'},
          });
        return jsonResponse({'status': 'PENDING'});
      });
      expect(
        (await api.startSoloCheckout(amount: 5, storage: storage))['status'],
        'cancelled',
      );
    },
  );
  test('Default payment window is ninety seconds', () {
    expect(SumupService().paymentWindow, const Duration(seconds: 90));
  });
  for (final outcome in ['cancelled', 'failed', 'successful']) {
    test(
      'Solo $outcome is returned immediately without requesting termination',
      () async {
        final storage = await StorageService.initialize();
        final api = service((r) async {
          if (r.method == 'POST') {
            expect(r.url.path, endsWith('/checkout'));
            final body = jsonDecode(r.body);
            expect(body['total_amount']['value'], 101);
            expect(body['affiliate']['foreign_transaction_id'], isNotEmpty);
            return accepted();
          }
          if (r.url.path.contains('/checkout/'))
            return jsonResponse({
              'data': {'status': outcome},
            });
          return jsonResponse({}, 404);
        });
        final result = await api.startSoloCheckout(
          amount: 1.01,
          storage: storage,
        );
        expect(result['status'], outcome);
        expect(result['success'], outcome == 'successful');
        expect(
          storage.getSumupPaymentJournal().join(),
          isNot(contains('fixture-sumup_api_key')),
        );
      },
    );
  }
  test(
    'User cancellation is sent to the terminal once and then confirmed',
    () async {
      final storage = await StorageService.initialize();
      int stops = 0;
      late SumupService api;
      api = service((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/checkout')) {
          await api.requestCancellation();
          await api.requestCancellation();
          return accepted();
        }
        if (r.url.path.endsWith('/terminate')) {
          stops++;
          return http.Response('', 204);
        }
        if (r.url.path.endsWith('/status')) return readerState();
        if (r.url.path.contains('/checkout/'))
          return jsonResponse({
            'data': {'status': stops > 0 ? 'cancelled' : 'pending'},
          });
        return jsonResponse({}, 404);
      }, window: const Duration(seconds: 90));
      final result = await api.startSoloCheckout(amount: 5, storage: storage);
      expect(stops, 1);
      expect(result['status'], 'cancelled');
    },
  );
  test(
    'Deadline begins only after a ready reader and cancels through SumUp',
    () async {
      final storage = await StorageService.initialize();
      int states = 0, stops = 0;
      final api = service((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/checkout'))
          return accepted();
        if (r.url.path.endsWith('/terminate')) {
          stops++;
          expect(states, greaterThanOrEqualTo(2));
          return http.Response('', 202);
        }
        if (r.url.path.endsWith('/status')) {
          states++;
          return readerState(states == 1 ? 'IDLE' : 'WAITING_FOR_CARD');
        }
        if (r.url.path.contains('/checkout/'))
          return jsonResponse({
            'data': {'status': stops > 0 ? 'cancelled' : 'pending'},
          });
        return jsonResponse({}, 404);
      }, activation: const Duration(seconds: 1));
      final result = await api.startSoloCheckout(amount: 5, storage: storage);
      expect(stops, 1);
      expect(result['status'], 'timed_out');
      expect(result['error'], contains('Délai de paiement dépassé'));
    },
  );
  test('A late financial approval wins over cancellation', () async {
    final storage = await StorageService.initialize();
    int stops = 0;
    final api = service((r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/checkout'))
        return accepted();
      if (r.url.path.endsWith('/terminate')) {
        stops++;
        return http.Response('', 204);
      }
      if (r.url.path.endsWith('/status')) return readerState();
      if (r.url.path.contains('/checkout/'))
        return jsonResponse({
          'data': {'status': stops > 0 ? 'cancelled' : 'pending'},
        });
      return stops > 0
          ? jsonResponse({'status': 'SUCCESSFUL', 'id': 'confirmed-payment'})
          : jsonResponse({}, 404);
    });
    final result = await api.startSoloCheckout(amount: 5, storage: storage);
    expect(result['success'], true);
    expect(result['transaction_id'], 'confirmed-payment');
  });
  test(
    'A financial approval just before terminate prevents the terminate call',
    () async {
      final storage = await StorageService.initialize();
      int checks = 0;
      final api = service((r) async {
        if (r.method == 'POST') {
          expect(r.url.path, endsWith('/checkout'));
          return accepted();
        }
        if (r.url.path.endsWith('/status')) return readerState();
        if (r.url.path.contains('/checkout/')) {
          checks++;
          return jsonResponse({
            'data': {'status': 'pending'},
          });
        }
        return checks > 1
            ? jsonResponse({'status': 'SUCCESSFUL', 'id': 'approved'})
            : jsonResponse({}, 404);
      });
      expect(
        (await api.startSoloCheckout(amount: 5, storage: storage))['success'],
        true,
      );
    },
  );
  test(
    'Cancellation does not force termination during bank processing',
    () async {
      final storage = await StorageService.initialize();
      late SumupService api;
      int stops = 0;
      api = service((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/checkout')) {
          await api.requestCancellation();
          return accepted();
        }
        if (r.url.path.endsWith('/terminate')) {
          stops++;
          return http.Response('', 204);
        }
        if (r.url.path.endsWith('/status')) return readerState('IDLE');
        if (r.url.path.contains('/checkout/'))
          return jsonResponse({
            'data': {'status': 'pending'},
          });
        return jsonResponse({'status': 'PENDING'});
      });
      expect(
        (await api.startSoloCheckout(amount: 5, storage: storage))['status'],
        'unknown',
      );
      expect(stops, 0);
    },
  );
  test(
    'Unknown reader state or offline state never confirms cancellation',
    () async {
      final storage = await StorageService.initialize();
      final api = service((r) async {
        if (r.method == 'POST') {
          expect(r.url.path, endsWith('/checkout'));
          return accepted();
        }
        if (r.url.path.endsWith('/status'))
          return readerState('WAITING_FOR_CARD', false);
        return jsonResponse({}, 404);
      });
      expect(
        (await api.startSoloCheckout(amount: 5, storage: storage))['status'],
        'unknown',
      );
    },
  );
  test(
    'A failed terminate response is never reported as a confirmed cancellation',
    () async {
      final storage = await StorageService.initialize();
      int stops = 0;
      final api = service((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/checkout'))
          return accepted();
        if (r.url.path.endsWith('/terminate')) {
          stops++;
          return jsonResponse({}, 503);
        }
        if (r.url.path.endsWith('/status')) return readerState();
        if (r.url.path.contains('/checkout/'))
          return jsonResponse({
            'data': {'status': 'pending'},
          });
        return jsonResponse({}, 404);
      });
      expect(
        (await api.startSoloCheckout(amount: 5, storage: storage))['status'],
        'unknown',
      );
      expect(stops, 1);
    },
  );
  test(
    'A definitive failure after accepted termination resolves without waiting ninety seconds',
    () async {
      final storage = await StorageService.initialize();
      bool stopped = false;
      final api = service((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/checkout'))
          return accepted();
        if (r.url.path.endsWith('/terminate')) {
          stopped = true;
          return http.Response('', 204);
        }
        if (r.url.path.endsWith('/status')) return readerState();
        if (r.url.path.contains('/checkout/'))
          return jsonResponse({
            'data': {'status': stopped ? 'failed' : 'pending'},
          });
        return jsonResponse({}, 404);
      });
      expect(
        (await api.startSoloCheckout(amount: 5, storage: storage))['status'],
        'timed_out',
      );
    },
  );
  test(
    'Network requests and unconfirmed results have bounded waits without POST retries',
    () async {
      final storage = await StorageService.initialize();
      int requests = 0;
      final api = service((r) {
        requests++;
        return Completer<http.Response>().future;
      });
      expect(
        (await api.startSoloCheckout(amount: 5, storage: storage))['status'],
        'unknown',
      );
      expect(requests, 1);
    },
  );
  test('Concurrent clicks create one checkout only', () async {
    final storage = await StorageService.initialize();
    final entered = Completer<void>(), reply = Completer<http.Response>();
    int posts = 0;
    final api = service((r) async {
      posts++;
      entered.complete();
      return reply.future;
    });
    final first = api.startSoloCheckout(amount: 5, storage: storage);
    await entered.future;
    expect(
      (await api.startSoloCheckout(amount: 10, storage: storage))['status'],
      'not_started',
    );
    reply.complete(jsonResponse({}, 503));
    await first;
    expect(posts, 1);
  });
  test('Rejected and ambiguous checkout requests are distinguished', () async {
    final storage = await StorageService.initialize();
    expect(
      (await service(
        (r) async => jsonResponse({}, 403),
      ).startSoloCheckout(amount: 5, storage: storage))['status'],
      'not_started',
    );
    expect(
      (await service(
        (r) async => jsonResponse({}, 503),
      ).startSoloCheckout(amount: 5, storage: storage))['status'],
      'unknown',
    );
  });
  testWidgets('Cancel appears at five seconds and cannot be clicked twice', (
    tester,
  ) async {
    final payment = Completer<Map<String, dynamic>>();
    int cancels = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => PaymentDialog(
                amount: 5,
                autoCloseFailures: true,
                paymentFuture: payment.future,
                statusStream: const Stream.empty(),
                onCancelPayment: () async {
                  cancels++;
                },
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4900));
    expect(find.text('Annuler le paiement'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Annuler le paiement'), findsOneWidget);
    await tester.tap(find.text('Annuler le paiement'));
    await tester.pump();
    expect(find.text('Annulation en cours…'), findsWidgets);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Annulation en cours…'),
          )
          .onPressed,
      isNull,
    );
    expect(cancels, 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(PaymentDialog), findsOneWidget);
    payment.complete({
      'success': false,
      'status': 'cancelled',
      'error': 'Annulé',
    });
    await tester.pump();
    expect(find.text('Fermer'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
  for (final status in [
    'successful',
    'failed',
    'cancelled',
    'timed_out',
    'unknown',
  ]) {
    testWidgets(
      '$status closes after five seconds and has no persistent verification UI',
      (tester) async {
        final payment = Completer<Map<String, dynamic>>();
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => PaymentDialog(
                    amount: 5,
                    autoCloseFailures: true,
                    paymentFuture: payment.future,
                    statusStream: const Stream.empty(),
                    onCancelPayment: () async {},
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        payment.complete({
          'success': status == 'successful',
          'status': status,
          'error': 'Result',
        });
        await tester.pump();
        if (status == 'unknown')
          expect(find.text('Résultat non confirmé'), findsOneWidget);
        if (status == 'timed_out')
          expect(find.text('Délai de paiement dépassé'), findsOneWidget);
        expect(find.text('Annuler le paiement'), findsNothing);
        await tester.pump(const Duration(milliseconds: 4900));
        expect(find.byType(PaymentDialog), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(find.byType(PaymentDialog), findsNothing);
      },
    );
  }
  testWidgets(
    'No recovery, startup network request or permanent lock after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'pos_is_mock_mode': true,
        'sumup_pending_payment': '{"amount_minor":500}',
      });
      final storage = await StorageService.initialize();
      int calls = 0;
      final api = service((r) async {
        calls++;
        return jsonResponse({}, 404);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(storageService: storage, sumupService: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Vérifier maintenant'), findsNothing);
      expect(find.text('Vérification du paiement en cours…'), findsNothing);
      expect(
        tester
            .widget<AbsorbPointer>(find.byType(AbsorbPointer).first)
            .absorbing,
        false,
      );
    },
  );
}
