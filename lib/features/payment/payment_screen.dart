// payment_screen.dart
//
// This is the primary checkout dashboard. It splits the widescreen layout into:
// - A beautiful sticky backdrop top bar with branding, connection status, and config gear.
// - A centered main section containing the basmalah placeholder, call to action text,
//   and checkout deck housing the AmountGrid quick checkout board.
// - A sticky backdrop bottom bar containing the custom horizontal stepper.
// It coordinates state transitions from Step 1 (Awaiting Amount) to Step 2 (Processing Card),
// and Step 3 (Captured & Approved) with real-time logging.
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../services/storage_service.dart';
import '../../services/stripe_service.dart';
import '../../services/sumup_service.dart';
import '../setup/setup_screen.dart';
import '../app_background.dart';
import 'widgets/amount_grid.dart';
import 'widgets/custom_stepper.dart';
import 'widgets/payment_dialog.dart';

class PaymentScreen extends StatefulWidget {
  final StorageService storageService;
  final SumupService sumupService;

  const PaymentScreen({
    super.key,
    required this.storageService,
    required this.sumupService,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final StripeService _stripeService = StripeService();
  bool _transactionActive = false;

  int _currentCheckoutStep = 1; // 1 = Select, 2 = Processing, 3 = Approved
  String? _logoFilePath;
  Uint8List? _logoBytes;
  String _translationText = '';
  bool _isMockMode = false;
  bool _isTestMode = false;
  bool _isStripe = false;
  String _associationName = '';
  String _shortText =
      'Soutenez notre association. Chaque contribution fait la différence.';

  @override
  void initState() {
    super.initState();
    _loadMerchantDetails();
  }

  /// Initialized the company logo path and mock status for local presentation.
  void _loadMerchantDetails() {
    setState(() {
      _logoFilePath = widget.storageService.getLogoPath();
      _logoBytes = widget.storageService.getLogoBytes();
      _translationText = widget.storageService.getTranslationText();
      _isMockMode = widget.storageService.isMockMode();
      _isTestMode = widget.storageService.isTestMode();
      _isStripe = widget.storageService.isStripe();
      _associationName = widget.storageService.getAssociationName();
      _shortText = widget.storageService.getShortText();
    });
  }

  /// Executes the transaction pipeline:
  /// Creates the async future, opens the transaction modal, pushes updates to a log stream,
  /// updates step phases, and manages post-approval UI reset.
  Future<void> _initiateTerminalTransaction(double amount) async {
    if (_transactionActive) return;
    _transactionActive = true;
    // Transition UI to Step 2 (Processing)
    setState(() {
      _currentCheckoutStep = 2;
    });

    // We instantiate a stream controller to broadcast direct status changes
    // from StripeService straight into the dialog box console.
    final StreamController<String> statusStreamController =
        StreamController<String>();

    // Start the transaction future
    final Future<Map<String, dynamic>> transactionFuture = _stripeService
        .processPayment(
          amount: amount,
          storage: widget.storageService,
          onStatusUpdate: (message) {
            statusStreamController.add(message);
          },
        );

    // Launch Checkout Dialog Box
    final bool? wasCaptured = await showDialog<bool>(
      context: context,
      barrierDismissible:
          false, // Prevent backdrop tapping from breaking connection
      builder: (context) {
        return PaymentDialog(
          amount: amount,
          neutralButtonColor: Color(
            widget.storageService.getDonationButtonColor(true),
          ),
          paymentFuture: transactionFuture,
          statusStream: statusStreamController.stream,
          onApproved: () {
            if (mounted) setState(() => _currentCheckoutStep = 3);
          },
        );
      },
    );

    // Close the logging stream
    await statusStreamController.close();

    if (wasCaptured == true) {
      // Transition UI to Step 3 (Approved & Finalized)
      setState(() {
        _currentCheckoutStep = 3;
      });

      // Display approval message or let the success state persist briefly
      await Future.delayed(const Duration(seconds: 1));
    }

    // Reset workflow to Step 1 (Awaiting selection)
    if (mounted) {
      setState(() {
        _currentCheckoutStep = 1;
        _transactionActive = false;
      });
    }
  }

  Future<void> _initiateSumupTransaction(double amount) async {
    if (!mounted || _transactionActive) return;
    setState(() {
      _transactionActive = true;
      _currentCheckoutStep = 2;
    });
    final statuses = StreamController<String>();
    final future = widget.sumupService.startSoloCheckout(
      amount: amount,
      storage: widget.storageService,
      onStatusUpdate: (message) {
        if (!statuses.isClosed) statuses.add(message);
      },
    );
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PaymentDialog(
          amount: amount,
          autoCloseFailures: true,
          onCancelPayment: widget.sumupService.requestCancellation,
          neutralButtonColor: Color(
            widget.storageService.getDonationButtonColor(true),
          ),
          paymentFuture: future,
          statusStream: statuses.stream,
          onApproved: () {
            if (mounted) setState(() => _currentCheckoutStep = 3);
          },
        ),
      );
    } finally {
      await statuses.close();
      if (mounted)
        setState(() {
          _transactionActive = false;
          _currentCheckoutStep = 1;
        });
    }
  }

  /// Reroutes to setup screen to update tokens or keys.
  void _navigateToSettings() {
    if (_transactionActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Un paiement est en cours. Les paramètres restent verrouillés.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SetupScreen(
          storageService: widget.storageService,
          sumupService: widget.sumupService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC9A55C);
    return Scaffold(
      body: AppBackground(
        bytes: widget.storageService.getBackgroundBytes(),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final compact = constraints.maxHeight < 850;
                    // Reserve the same space on both sides, independently of the
                    // selected logo size, so the basmala stays centred on screen.
                    final maxLogoWidth = ((width < 500 ? 80.0 : 140.0) * 1.6)
                        .clamp(40.0, (width - 48) * 0.25);
                    final settingsWidth = width < 500 ? 80.0 : 160.0;
                    final sideWidth = maxLogoWidth > settingsWidth
                        ? maxLogoWidth
                        : settingsWidth;
                    final headerHeight = compact ? 140.0 : 176.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: width),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: sideWidth,
                                    height: headerHeight,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        key: const ValueKey('header-logo'),
                                        width:
                                            ((width < 500 ? 80.0 : 140.0) *
                                                    widget.storageService
                                                        .getLogoScale())
                                                .clamp(
                                                  40.0,
                                                  (width - 48) * 0.25,
                                                ),
                                        height:
                                            ((width < 500 ? 84.0 : 110.0) *
                                                    widget.storageService
                                                        .getLogoScale())
                                                .clamp(
                                                  42.0,
                                                  compact ? 140.0 : 176.0,
                                                ),
                                        child: _logoBytes != null
                                            ? Image.memory(
                                                _logoBytes!,
                                                fit: BoxFit.contain,
                                              )
                                            : !kIsWeb && _logoFilePath != null
                                            ? Image.file(
                                                File(_logoFilePath!),
                                                fit: BoxFit.contain,
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Image.asset(
                                      'assets/legacy/basmalah.png',
                                      key: const ValueKey('header-basmala'),
                                      height: compact ? 84 : 140,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: sideWidth,
                                    height: headerHeight,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: RawGestureDetector(
                                        key: const ValueKey(
                                          'hidden-settings-access',
                                        ),
                                        behavior: HitTestBehavior.opaque,
                                        gestures: {
                                          LongPressGestureRecognizer:
                                              GestureRecognizerFactoryWithHandlers<
                                                LongPressGestureRecognizer
                                              >(
                                                () =>
                                                    LongPressGestureRecognizer(
                                                      duration: const Duration(
                                                        seconds: 5,
                                                      ),
                                                    ),
                                                (recognizer) =>
                                                    recognizer.onLongPress =
                                                        _navigateToSettings,
                                              ),
                                        },
                                        child: SizedBox(
                                          width: width < 500 ? 80 : 160,
                                          height: compact ? 84 : 140,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: double.infinity,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _shortText.replaceAll('\n', ' '),
                                    maxLines: 1,
                                    softWrap: false,
                                    textDirection:
                                        RegExp(
                                          r'[\u0600-\u06FF]',
                                        ).hasMatch(_shortText)
                                        ? TextDirection.rtl
                                        : TextDirection.ltr,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: widget.storageService
                                          .getTextFont('main'),
                                      fontSize: widget.storageService
                                          .getTextSize('main'),
                                      height: 1.5,
                                      color: Color(
                                        widget.storageService.getTextColor(
                                          'main',
                                        ),
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_translationText.isNotEmpty)
                                Text(
                                  _translationText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: widget.storageService
                                        .getTextFont('translation'),
                                    fontSize:
                                        widget.storageService.getTextSize(
                                          'translation',
                                        ) *
                                        (width / 1080).clamp(0.6, 1.0),
                                    fontWeight: FontWeight.bold,
                                    height: 1.4,
                                    color: Color(
                                      widget.storageService.getTextColor(
                                        'translation',
                                      ),
                                    ),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              if (_associationName.trim().isNotEmpty)
                                Text(
                                  _associationName,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: widget.storageService
                                        .getTextFont('association'),
                                    fontSize:
                                        widget.storageService.getTextSize(
                                          'association',
                                        ) *
                                        (width / 1080).clamp(0.6, 1.0),
                                    fontWeight: FontWeight.bold,
                                    color: Color(
                                      widget.storageService.getTextColor(
                                        'association',
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                _isMockMode
                                    ? 'MODE SIMULATEUR'
                                    : _isTestMode
                                    ? 'MODE TEST'
                                    : 'TERMINAL EN LIGNE',
                                style: TextStyle(
                                  color: _isMockMode
                                      ? const Color(0xFFD97706)
                                      : _isTestMode
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF15803D),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 9,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, gridSpace) {
                                    final gridWidth = gridSpace.maxWidth.clamp(
                                      0.0,
                                      770.0,
                                    );
                                    final scale = gridWidth / 770;
                                    final availableHeight =
                                        ((gridSpace.maxHeight -
                                                    24 -
                                                    60 * scale) /
                                                3)
                                            .clamp(1.0, 430.0 * scale);
                                    return Align(
                                      alignment: Alignment.topCenter,
                                      child: SizedBox(
                                        width: gridWidth,
                                        child: AbsorbPointer(
                                          absorbing: _transactionActive,
                                          child: AmountGrid(
                                            buttonSize: availableHeight / scale,
                                            amountColor: Color(
                                              widget.storageService
                                                  .getDonationButtonColor(
                                                    false,
                                                  ),
                                            ),
                                            customColor: Color(
                                              widget.storageService
                                                  .getDonationButtonColor(true),
                                            ),
                                            onAmountSelected:
                                                _isStripe || _isMockMode
                                                ? _initiateTerminalTransaction
                                                : _initiateSumupTransaction,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                color: const Color(0xFFEDEDED),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 8,
                ),
                child: CustomStepper(
                  currentStep: _currentCheckoutStep,
                  color: gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
