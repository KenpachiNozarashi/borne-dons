import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:borne_dons/features/setup/setup_screen.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:borne_dons/features/payment/widgets/payment_dialog.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:borne_dons/services/storage_service.dart';
import 'package:borne_dons/services/sumup_service.dart';
import 'package:borne_dons/features/payment/payment_screen.dart';
import 'package:borne_dons/features/payment/widgets/amount_grid.dart';

void main() {
  Widget app(void Function(double) selected) => MaterialApp(home: Scaffold(
    body: SingleChildScrollView(child: AmountGrid(buttonSize: 110, onAmountSelected: selected))));

  testWidgets('Preset sends its amount once', (tester) async {
    final received = <double>[];
    await tester.pumpWidget(app(received.add));
    await tester.ensureVisible(find.text('5 €'));
    await tester.tap(find.text('5 €'));
    expect(received, [5.0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Keypad validates only a positive amount', (tester) async {
    final received = <double>[];
    await tester.pumpWidget(app(received.add));
    await tester.ensureVisible(find.text('Autre\nmontant'));
    await tester.tap(find.text('Autre\nmontant'));
    await tester.pumpAndSettle();
    expect(tester.widget<DonationButton>(find.widgetWithText(DonationButton, 'Valider')).onTap, isNull);
    await tester.ensureVisible(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.ensureVisible(find.text('2'));
    await tester.tap(find.text('2'));
    await tester.ensureVisible(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.ensureVisible(find.text('0'));
    await tester.tap(find.text('0'));
    await tester.ensureVisible(find.text('9'));
    await tester.tap(find.text('9'));
    await tester.pump();
    expect(find.text('12509 €'), findsOneWidget);
    expect(find.text('Ajouter une virgule'), findsNothing);
    await tester.ensureVisible(find.text('Valider'));
    await tester.ensureVisible(find.text('Valider'));
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(received, [12509.0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel never starts a payment', (tester) async {
    final received = <double>[];
    await tester.pumpWidget(app(received.add));
    await tester.ensureVisible(find.text('Autre\nmontant'));
    await tester.tap(find.text('Autre\nmontant'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.ensureVisible(find.text('Annuler'));
    await tester.ensureVisible(find.text('Annuler'));
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(received, isEmpty);
    expect(find.text('Saisissez votre montant'), findsNothing);
  });
  for (final size in [const Size(390, 844), const Size(1440, 900), const Size(1080, 1920)]) {
    testWidgets('Donation screen fits $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'pos_is_mock_mode': true});
      final storage = await StorageService.initialize();
      await tester.pumpWidget(MaterialApp(home: PaymentScreen(storageService: storage, sumupService: SumupService())));
      await tester.pumpAndSettle();
      expect(find.text('MODE SIMULATEUR'), findsOneWidget);
      expect(tester.getBottomRight(find.text('Autre\nmontant')).dy, lessThan(size.height));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Original button dimensions and mouse hover', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: Center(child: SizedBox(width: 770, child: AmountGrid(buttonSize: 430, onAmountSelected: (_) {}))),
    ))));
    final button = find.ancestor(of: find.text('5 €'), matching: find.byType(AnimatedScale));
    expect(tester.getSize(button), const Size(370, 430));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(0, 0));
    await mouse.moveTo(tester.getCenter(button));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(button).scale, 1.02);
    await mouse.moveTo(const Offset(0, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(button).scale, 1);
    await mouse.removePointer();
  });

  testWidgets('Custom call and translation replace default verse', (tester) async {
    SharedPreferences.setMockInitialValues({'pos_is_mock_mode': true});
    final storage = await StorageService.initialize();
    await storage.setShortText('Aidez notre association');
    await storage.setTranslationText('Chaque don compte');
    await tester.pumpWidget(MaterialApp(home: PaymentScreen(storageService: storage, sumupService: SumupService())));
    await tester.pumpAndSettle();
    expect(find.text('Aidez notre association'), findsOneWidget);
    expect(find.text('Chaque don compte'), findsOneWidget);
    expect(find.textContaining('Si vous faites à Allah'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Imported logo persists and can be removed', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.initialize();
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    await storage.saveLogoBytes(bytes);
    final reloaded = await StorageService.initialize();
    expect(reloaded.getLogoBytes(), orderedEquals(bytes));
    await reloaded.clearLogo();
    expect(reloaded.getLogoBytes(), isNull);
  });

  testWidgets('Approval is reported while payment dialog is still open', (tester) async {
    final payment = Completer<Map<String, dynamic>>();
    var approved = false;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () => showDialog<bool>(context: context, builder: (_) => PaymentDialog(
        amount: 5, paymentFuture: payment.future, statusStream: const Stream.empty(),
        onApproved: () => approved = true,
      )), child: const Text('Ouvrir')),
    ))));
    await tester.tap(find.text('Ouvrir'));
    await tester.pump();
    expect(approved, isFalse);
    payment.complete({'success': true});
    await tester.pump();
    expect(approved, isTrue);
    expect(find.text('Merci pour votre don !'), findsOneWidget);
    expect(find.text('جَزَاكُمْ اللَّهُ خَيْرًا'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentDialog), findsNothing);
  });

  testWidgets('Repeated leading zeros stay unique and are replaced by a digit', (tester) async {
    final received = <double>[];
    await tester.pumpWidget(app(received.add));
    await tester.tap(find.text('Autre\nmontant'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('0'));
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.text('0'));
      await tester.pump();
    }
    expect(find.text('0 €'), findsOneWidget);
    expect(tester.widget<DonationButton>(find.widgetWithText(DonationButton, 'Valider')).onTap, isNull);
    await tester.ensureVisible(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(find.text('5 €'), findsNWidgets(2));
    await tester.ensureVisible(find.text('0'));
    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('50 €'), findsNWidgets(2));
    await tester.ensureVisible(find.text('Valider'));
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(received, [50.0]);
  });

  test('Each text keeps independent colour, font and size', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.initialize();
    await storage.setTextAppearance('main', 0xFF123456, 48, 'Amiri');
    await storage.setTextAppearance('translation', 0xFF654321, 20, 'ReemKufi');
    final reloaded = await StorageService.initialize();
    expect(reloaded.getTextColor('main'), 0xFF123456);
    expect(reloaded.getTextSize('main'), 48);
    expect(reloaded.getTextFont('main'), 'Amiri');
    expect(reloaded.getTextColor('translation'), 0xFF654321);
    expect(reloaded.getTextSize('translation'), 20);
    expect(reloaded.getTextSize('association'), 40);
  });

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('Hidden settings requires five seconds with $kind', (tester) async {
      SharedPreferences.setMockInitialValues({'pos_is_mock_mode': true});
      const secureChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(secureChannel, (_) async => null);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(secureChannel, null));
      final storage = await StorageService.initialize();
      await tester.pumpWidget(MaterialApp(home: PaymentScreen(storageService: storage, sumupService: SumupService())));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.settings_outlined), findsNothing);
      final target = tester.getCenter(find.byKey(const ValueKey('hidden-settings-access')));
      final gesture = await tester.startGesture(target, kind: kind);
      await tester.pump(const Duration(milliseconds: 4900));
      expect(find.byType(SetupScreen), findsNothing);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(SetupScreen), findsNothing);
      final hold = await tester.startGesture(target, kind: kind);
      await tester.pump(const Duration(seconds: 5));
      await hold.up();
      await tester.pumpAndSettle();
      expect(find.byType(SetupScreen), findsOneWidget);
    });
  }

}
