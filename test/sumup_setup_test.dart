import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:borne_dons/services/sumup_service.dart';
import 'package:borne_dons/services/storage_service.dart';
import 'package:borne_dons/services/windows_sumup_client.dart';
import 'package:borne_dons/features/setup/setup_screen.dart';
import 'package:borne_dons/features/payment/payment_screen.dart';

const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Pairing uses one POST and validates the returned reader', () async {
    var calls = 0;
    final api = SumupService(
      client: MockClient((r) async {
        calls++;
        expect(r.method, 'POST');
        expect(r.url.host, 'api.sumup.com');
        expect(jsonDecode(r.body)['pairing_code'], 'fixture-code');
        return http.Response('{"id":"reader-fixture"}', 201);
      }),
    );
    expect(
      await api.pairSumupSolo('merchant', 'fixture-key', 'fixture-code'),
      'reader-fixture',
    );
    expect(calls, 1);
  });
  for (final status in [400, 401, 403, 409, 422, 429, 500]) {
    test(
      'Pairing HTTP $status is visible and never leaks the response body',
      () async {
        final api = SumupService(
          client: MockClient(
            (_) async => http.Response('SECRET-FIXTURE', status),
          ),
        );
        await expectLater(
          api.pairSumupSolo('merchant', 'fixture-key', 'fixture-code'),
          throwsA(
            isA<SumupSetupException>().having(
              (e) => e.message.contains('SECRET-FIXTURE'),
              'no secret',
              false,
            ),
          ),
        );
      },
    );
  }
  test('An empty reader ID is never accepted', () async {
    final api = SumupService(
      client: MockClient((_) async => http.Response('{"id":""}', 201)),
    );
    await expectLater(
      api.pairSumupSolo('merchant', 'fixture-key', 'fixture-code'),
      throwsA(isA<SumupSetupException>()),
    );
  });
  test('Pairing timeout aborts the request without retry', () async {
    var sends = 0;
    final aborted = Completer<void>();
    final api = SumupService(
      pairingTimeout: const Duration(milliseconds: 20),
      client: _HangingClient(() => sends++, aborted),
    );
    await expectLater(
      api.pairSumupSolo('merchant', 'fixture-key', 'fixture-code'),
      throwsA(isA<SumupSetupException>()),
    );
    await aborted.future.timeout(const Duration(seconds: 1));
    expect(sends, 1);
  });
  test(
    'Native client rejects credential-bearing HTTP and foreign endpoints',
    () async {
      final client = WindowsSumupClient();
      for (final url in [
        'http://api.sumup.com/',
        'https://example.com/',
        'https://api.sumup.com:444/',
        'https://user:secret@api.sumup.com/',
      ]) {
        await expectLater(
          client.get(Uri.parse(url)),
          throwsA(isA<http.ClientException>()),
        );
      }
      client.close();
    },
  );
  for (final fail in [true, false]) {
    testWidgets(
      'Initialisation ${fail ? 'shows pairing failure' : 'opens donations'}',
      (tester) async {
        tester.view.resetPhysicalSize();
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'pos_is_mock_mode': false,
          'pos_is_stripe': false,
        });
        final values = <String, String>{
          'sumup_merchant_code': 'fixture-merchant',
          'sumup_api_key': 'sup_sk_fixture',
          'sumup_app_id': 'fixture-app',
          'sumup_affiliation_key': 'sup_afk_fixture',
          'sumup_pairing_code': 'fixture-code',
        };
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            final args = call.arguments as Map;
            if (call.method == 'read') return values[args['key']];
            if (call.method == 'write') values[args['key']] = args['value'];
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        var pairs = 0;
        final api = SumupService(
          client: MockClient((_) async {
            pairs++;
            return http.Response(
              fail ? 'SECRET-FIXTURE' : '{"id":"fixture-reader"}',
              fail ? 403 : 201,
            );
          }),
        );
        final storage = await StorageService.initialize();
        await tester.pumpWidget(
          MaterialApp(
            home: SetupScreen(storageService: storage, sumupService: api),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Initialiser la borne'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Initialiser la borne'));
        await tester.pumpAndSettle();
        expect(
          pairs,
          1,
          reason: 'Same pairing code but missing reader must still pair.',
        );
        if (fail) {
          expect(find.byType(SetupScreen), findsOneWidget);
          expect(find.textContaining('Accès SumUp refusé'), findsOneWidget);
          expect(find.textContaining('SECRET-FIXTURE'), findsNothing);
          expect(
            tester
                .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Initialiser la borne'),
                )
                .onPressed,
            isNotNull,
          );
        } else {
          expect(find.byType(PaymentScreen), findsOneWidget);
          expect(await storage.getSumupReaderId(), 'fixture-reader');
        }
      },
    );
  }
}

class _HangingClient extends http.BaseClient {
  final void Function() sent;
  final Completer<void> aborted;
  _HangingClient(this.sent, this.aborted);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) async {
    sent();
    await (r as http.Abortable).abortTrigger;
    aborted.complete();
    throw http.RequestAbortedException(r.url);
  }
}
