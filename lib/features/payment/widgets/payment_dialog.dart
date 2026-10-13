/// payment_dialog.dart
///
/// A highly polished checkout dialog that communicates directly with the reader.
/// It uses a stream of logs/messages to show the user and merchant the reader handshake status.
/// It includes visual indicators (using elegant CustomPainters for loading pulses and green approvals)
/// with a structural option to swap in Lottie JSON assets for production.
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import 'amount_grid.dart';

class PaymentDialog extends StatefulWidget {
  final double amount;
  final Color neutralButtonColor;
  final Future<Map<String, dynamic>> paymentFuture;
  final Stream<String> statusStream;
  final VoidCallback? onApproved;

  const PaymentDialog({
    Key? key,
    required this.amount,
    this.neutralButtonColor = const Color(0xFF757479),
    required this.paymentFuture,
    required this.statusStream,
    this.onApproved,
  }) : super(key: key);

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _checkController;
  
  StreamSubscription<String>? _statusSubscription;
  String _latestStatus = 'Initialisation du terminal...';
  bool _isSuccess = false;
  bool _isConfirmed = false;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    
    // Pulse animation controller for the loading state
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Scale/Draw animation controller for the success checkmark
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Subscribe to status updates from the Stripe API
    _statusSubscription = widget.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _latestStatus = status;
        });
      }
    });

    // Handle transaction completion
    widget.paymentFuture.then((result) {
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _isSuccess = true;
          _isConfirmed = result['payment_confirmed'] != false;
        });
        if (_isConfirmed) widget.onApproved?.call();
        _pulseController.stop();
        _checkController.forward();
        // Delay and auto-dismiss on success
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            Navigator.of(context).pop(_isConfirmed); // Return confirmed success
          }
        });
      } else {
        setState(() {
          _isError = true;
          _errorMessage = result['error'] ?? 'Une erreur s\'est produite.';
        });
        _pulseController.stop();
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _pulseController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Visual Status Indicator ---
              SizedBox(
                height: 120,
                width: 120,
                child: Center(
                  child: _buildVisualState(),
                ),
              ),
              const SizedBox(height: 24.0),

              // --- Charge Details ---
              Text(
                _isSuccess ? (_isConfirmed ? 'Merci pour votre don !' : 'Paiement autorisé') : (_isError ? 'Paiement refusé' : 'Paiement en cours'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'ReemKufi',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: _isConfirmed ? const Color(0xFFC9A55C) : AppConstants.foreground,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                '${widget.amount.toStringAsFixed(2)} EUR',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.foreground,
                ),
              ),
              const SizedBox(height: 20.0),

              if (_isConfirmed) ...[
                const Text('جَزَاكُمْ اللَّهُ خَيْرًا',
                  textDirection: TextDirection.rtl, textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 44, fontWeight: FontWeight.normal,
                    color: Color(0xFFC9A55C), height: 1.5)),
                const SizedBox(height: 20),
                const Text('Votre paiement a bien été validé.', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24)),
                const SizedBox(height: 24),
                SizedBox(width: 200, height: 72,
                  child: DonationButton(label: 'Quitter', grey: true, baseColor: widget.neutralButtonColor, fontSize: 24, subtle: true,
                    onTap: () => Navigator.of(context).pop(true))),
              ],
              // --- Logs Console / Status Messages ---
              if (!_isConfirmed) Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppConstants.secondary,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: AppConstants.border, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ÉTAT DU PAIEMENT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppConstants.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      _isError ? _errorMessage : _latestStatus,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 20,
                        color: _isError ? AppConstants.error : AppConstants.foreground,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
              
              if (_isError) ...[
                const SizedBox(height: 24.0),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppConstants.border),
                    ),
                    child: const Text('Fermer', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the visual representation for the current transaction status.
  Widget _buildVisualState() {
    if (_isSuccess) {
      // Scale-in Checkmark circle
      return ScaleTransition(
        scale: CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
        child: Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: AppConstants.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            color: Colors.white,
            size: 44,
          ),
        ),
      );
    }

    if (_isError) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppConstants.error.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.error_outline,
          color: AppConstants.error,
          size: 44,
        ),
      );
    }

    // Processing Pulsing Circle (Minimalist loading indicator)
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 60 + (30 * _pulseController.value),
              height: 60 + (30 * _pulseController.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppConstants.primary.withOpacity(0.15 * (1.0 - _pulseController.value)),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppConstants.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.contactless_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        );
      },
    );
  }
}
