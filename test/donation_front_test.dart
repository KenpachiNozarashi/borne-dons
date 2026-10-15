import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:borne_dons/features/setup/setup_screen.dart';
import 'dart:typed_data';
import 'dart:convert';
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
  Widget app(void Function(double) selected) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: AmountGrid(buttonSize: 110, onAmountSelected: selected),
      ),
    ),
  );

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
    expect(
      tester
          .widget<DonationButton>(
            find.widgetWithText(DonationButton, 'Valider'),
          )
          .onTap,
      isNull,
    );
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
  for (final size in [
    const Size(390, 844),
    const Size(1440, 900),
    const Size(1080, 1920),
  ]) {
    testWidgets('Donation screen fits $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'pos_is_mock_mode': true});
      final storage = await StorageService.initialize();
      final image = (await rootBundle.load(
        'assets/legacy/basmalah.png',
      )).buffer.asUint8List();
      await storage.saveLogoBytes(image);
      await storage.setLogoScale(1.6);
      await storage.setBackgroundBytes(image);
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(
            storageService: storage,
            sumupService: SumupService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('MODE SIMULATEUR'), findsOneWidget);
      expect(
        tester.getBottomRight(find.text('Autre\nmontant')).dy,
        lessThan(size.height),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Original button dimensions and mouse hover', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 770,
                child: AmountGrid(buttonSize: 430, onAmountSelected: (_) {}),
              ),
            ),
          ),
        ),
      ),
    );
    final button = find.ancestor(
      of: find.text('5 €'),
      matching: find.byType(AnimatedScale),
    );
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

  testWidgets('Custom call and translation replace default verse', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'pos_is_mock_mode': true});
    final storage = await StorageService.initialize();
    await storage.setShortText('Aidez notre association');
    await storage.setTranslationText('Chaque don compte');
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentScreen(
          storageService: storage,
          sumupService: SumupService(),
        ),
      ),
    );
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

  testWidgets('Approval is reported while payment dialog is still open', (
    tester,
  ) async {
    final payment = Completer<Map<String, dynamic>>();
    var approved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => PaymentDialog(
                  amount: 5,
                  paymentFuture: payment.future,
                  statusStream: const Stream.empty(),
                  onApproved: () => approved = true,
                ),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
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

  testWidgets(
    'Repeated leading zeros stay unique and are replaced by a digit',
    (tester) async {
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
      expect(
        tester
            .widget<DonationButton>(
              find.widgetWithText(DonationButton, 'Valider'),
            )
            .onTap,
        isNull,
      );
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
    },
  );

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
    testWidgets('Hidden settings requires five seconds with $kind', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'pos_is_mock_mode': true});
      const secureChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        secureChannel,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          secureChannel,
          null,
        ),
      );
      final storage = await StorageService.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(
            storageService: storage,
            sumupService: SumupService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.settings_outlined), findsNothing);
      final target = tester.getCenter(
        find.byKey(const ValueKey('hidden-settings-access')),
      );
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

  test(
    'Default verse includes both closing brackets and keeps saved overrides',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.initialize();
      expect(
        storage.getShortText(),
        '﴿إِن تُقْرِضُوا اللَّهَ قَرْضًا حَسَنًا يُضَاعِفْهُ لَكُمْ وَيَغْفِرْ لَكُمْ ۚ وَاللَّهُ شَكُورٌ حَلِيمٌ﴾ [التغابن : ١٧]',
      );
      await storage.setShortText('Texte personnalisé');
      expect(storage.getShortText(), 'Texte personnalisé');
    },
  );

  testWidgets(
    'New installation has no logo and displays a generic association title',
    (tester) async {
      SharedPreferences.setMockInitialValues({'pos_is_mock_mode': true});
      final storage = await StorageService.initialize();
      expect(storage.getAssociationName(), 'Votre association');
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(
            storageService: storage,
            sumupService: SumupService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.business_outlined), findsNothing);
      expect(find.text('Votre association'), findsOneWidget);
      expect(storage.getLogoBytes(), isNull);
      expect(storage.getLogoPath(), isNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('header-logo')),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      await storage.setAssociationName('Association personnalisée');
      expect(storage.getAssociationName(), 'Association personnalisée');
      final reloaded = await StorageService.initialize();
      expect(reloaded.getAssociationName(), 'Association personnalisée');
      await reloaded.setAssociationName('');
      expect(reloaded.getAssociationName(), '');
    },
  );

  test('Logo size and custom background survive reload and export', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.initialize();
    final bytes = Uint8List.fromList([1, 2, 3]);
    await storage.setLogoScale(1.5);
    await storage.setBackgroundBytes(bytes);
    final exported = storage.exportAppearance();
    final reloaded = await StorageService.initialize();
    expect(reloaded.getLogoScale(), 1.5);
    expect(reloaded.getBackgroundBytes(), bytes);
    await reloaded.setBackgroundBytes(null);
    await reloaded.setLogoScale(1);
    expect(reloaded.getBackgroundBytes(), isNull);
    await reloaded.importAppearance(exported);
    expect(reloaded.getLogoScale(), 1.5);
    expect(reloaded.getBackgroundBytes(), bytes);
    expect(
      () => StorageService.decodeAppearance(
        jsonEncode({
          'format': 'borne-appearance-v1',
          'settings': {'logo_scale': 99},
        }),
      ),
      throwsFormatException,
    );
  });

  for (final dirty in [false, true]) {
    testWidgets('Cancel settings preserves saved values (dirty=$dirty)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'pos_is_mock_mode': true,
        'association_name': 'Association enregistrée',
        'logo_scale': 1.5,
      });
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final storage = await StorageService.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: SetupScreen(
            storageService: storage,
            sumupService: SumupService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (dirty) {
        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.controller?.text == 'Association enregistrée',
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, 'Modification non enregistrée');
        await tester.ensureVisible(
          find.text('Rétablir la taille de base du logo'),
        );
        await tester.tap(find.text('Rétablir la taille de base du logo'));
      }
      final cancel = find.byKey(const ValueKey('cancel-settings'));
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      if (dirty) {
        expect(find.text('Abandonner les modifications ?'), findsOneWidget);
        await tester.tap(find.text('Continuer les modifications'));
        await tester.pumpAndSettle();
        expect(find.byType(SetupScreen), findsOneWidget);
        await tester.ensureVisible(cancel);
        await tester.pumpAndSettle();
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quitter sans enregistrer'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(storage.getAssociationName(), 'Association enregistrée');
      expect(storage.getLogoScale(), 1.5);
    });
  }

  testWidgets('Visual import remains a draft and is discarded by Cancel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'pos_is_mock_mode': true,
      'association_name': 'Original',
    });
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final storage = await StorageService.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          storageService: storage,
          sumupService: SumupService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Importer les réglages visuels'));
    await tester.tap(find.text('Importer les réglages visuels'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      jsonEncode({
        'format': 'borne-appearance-v1',
        'settings': {'association_name': 'Importé', 'logo_scale': 1.6},
      }),
    );
    await tester.tap(find.text('Importer'));
    await tester.pumpAndSettle();
    expect(storage.getAssociationName(), 'Original');
    expect(storage.getLogoScale(), 1);
    final cancel = find.byKey(const ValueKey('cancel-settings'));
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitter sans enregistrer'));
    await tester.pumpAndSettle();
    expect(storage.getAssociationName(), 'Original');
  });
  testWidgets(
    'Initialiser commits the staged size and first setup cannot cancel',
    (tester) async {
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: SetupScreen(
            storageService: storage,
            sumupService: SumupService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('cancel-settings')),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Importer les réglages visuels'));
      await tester.tap(find.text('Importer les réglages visuels'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        jsonEncode({
          'format': 'borne-appearance-v1',
          'settings': {
            'association_name': 'Nouvelle association',
            'logo_scale': 1.6,
          },
        }),
      );
      await tester.tap(find.text('Importer'));
      await tester.pumpAndSettle();
      expect(storage.getLogoScale(), 1);
      await tester.ensureVisible(find.byType(Switch).first);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Initialiser la borne'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Initialiser la borne'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(storage.getLogoScale(), 1.6);
      expect(storage.getAssociationName(), 'Nouvelle association');
    },
  );
  testWidgets('Basmala stays centred and stationary for every logo size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final image = (await rootBundle.load(
      'assets/legacy/basmalah.png',
    )).buffer.asUint8List();
    for (final size in [
      const Size(390, 844),
      const Size(1440, 900),
      const Size(1080, 1920),
    ]) {
      tester.view.physicalSize = size;
      SharedPreferences.setMockInitialValues({'pos_is_mock_mode': true});
      final storage = await StorageService.initialize();
      await storage.saveLogoBytes(image);
      Offset? originalCenter;
      double? originalTextTop;
      for (final scale in [0.5, 1.0, 1.6]) {
        await storage.setLogoScale(scale);
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentScreen(
              key: ValueKey('$size-$scale'),
              storageService: storage,
              sumupService: SumupService(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final basmala = tester.getRect(
          find.byKey(const ValueKey('header-basmala')),
        );
        final logo = tester.getRect(find.byKey(const ValueKey('header-logo')));
        final textTop = tester.getTopLeft(find.text(storage.getShortText())).dy;
        expect(basmala.center.dx, closeTo(size.width / 2, 0.01));
        originalCenter ??= basmala.center;
        originalTextTop ??= textTop;
        expect(basmala.center, originalCenter);
        expect(textTop, originalTextTop);
        expect(logo.right, lessThan(basmala.left));
        expect(tester.takeException(), isNull);
      }
    }
  });
}
