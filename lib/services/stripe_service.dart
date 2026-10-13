/// stripe_service.dart
///
/// This service encapsulates the direct integration with the Stripe Terminal Cloud API.
/// Since this is a backend-less POS, the client handles request construction, headers,
/// and polling directly. It also implements a realistic Mock Simulation for demonstrations
/// when mock mode is enabled or invalid keys are supplied.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import '../core/constants.dart';

class StripeService {
  final http.Client _client;

  StripeService({http.Client? client}) : _client = client ?? http.Client();

  /// Processes a payment through the Stripe Terminal.
  /// 
  /// Step 1: Create a PaymentIntent with payment_method_types=['card_present'].
  /// Step 2: Push the PaymentIntent to the physical terminal reader using its reader ID.
  /// Step 3: Poll the PaymentIntent status until it completes, fails, or times out.
  Future<Map<String, dynamic>> processPayment({
    required double amount,
    required StorageService storage,
    void Function(String message)? onStatusUpdate,
  }) async {
    final isMock = storage.isMockMode();
    final isTest = storage.isTestMode();
    final secretKey = await storage.getStripeSecretKey() ?? '';
    final readerId = await storage.getTerminalId() ?? '';

    if (isMock || secretKey.isEmpty || readerId.isEmpty) {
      // Execute simulated payment flow for offline/mock usage
      return await _simulateTerminalPayment(amount, onStatusUpdate);
    }

    // Convert decimal amount to integer cents (Stripe requirement)
    final int amountInCents = (amount * 100).round();

    try {
      // ----------------------------------------------------
      // STEP 1: Create a Payment Intent
      // ----------------------------------------------------
      onStatusUpdate?.call('Initialisation du paiement ($amountInCents¢)...');
      
      // Payment intent
      final intentResponse = await _client.post(
        Uri.parse(AppConstants.paymentIntentsEndpoint),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amountInCents.toString(),
          'currency': 'eur',
          'payment_method_types[]': 'card_present',
          'capture_method': 'automatic', // automatically capture upon authorization
        },
      );

      //Catch intent error
      if (intentResponse.statusCode != 200) {
        final errorBody = jsonDecode(intentResponse.body);
        throw Exception('Impossible d\'initier le paiement: ${errorBody['error']?['message'] ?? intentResponse.body}');
      }

      //catch intent data
      final intentData = jsonDecode(intentResponse.body);
      final String intentId = intentData['id'];
      onStatusUpdate?.call('Paiement initialisé: $intentId');

      // ----------------------------------------------------
      // STEP 2: Wake up Reader and Hand off the Payment Intent
      // ----------------------------------------------------
      onStatusUpdate?.call('Connexion au terminal ($readerId)...');
      
      //activate reader
      final processUrl = AppConstants.processPaymentEndpoint(readerId);
      final processResponse = await _client.post(
        Uri.parse(processUrl),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'payment_intent': intentId,
        },
      );

      //catch reader activation error
      if (processResponse.statusCode != 200) {
        final errorBody = jsonDecode(processResponse.body);
        throw Exception('Connexion au terminal échouée: ${errorBody['error']?['message'] ?? processResponse.body}');
      }

      onStatusUpdate?.call('Terminal activé. Presentez votre carte...');

      //simulate payment with stripe
      if(isTest){
        final testPaymentUrl = AppConstants.simulateCardTap(readerId);
        final presentSimulatedCard = await _client.post(
          Uri.parse(testPaymentUrl),
          headers: {
            'Authorization': 'Bearer $secretKey',
            'Content-Type': 'application/x-www-form-urlencoded',
          }
        );
      }


      // ----------------------------------------------------
      // STEP 3: Poll PaymentIntent Status
      // ----------------------------------------------------
      // poll the Stripe payment intent status every 2 seconds
      // until it transitions out of processing/requires_payment_method states.
      final int maxPollAttempts = 30; // 60 seconds timeout
      for (int attempt = 0; attempt < maxPollAttempts; attempt++) {
        await Future.delayed(const Duration(seconds: 2));

        final checkUrl = '${AppConstants.paymentIntentsEndpoint}/$intentId';
        final checkResponse = await _client.get(
          Uri.parse(checkUrl),
          headers: {
            'Authorization': 'Bearer $secretKey',
          },
        );

        if (checkResponse.statusCode == 200) {
          final checkData = jsonDecode(checkResponse.body);
          final String status = checkData['status'];
          onStatusUpdate?.call('Lecture de la carte en cours: Status "$status"...');

          if (status == 'succeeded') {
            return {
              'success': true,
              'intent_id': intentId,
              'message': 'Paiement autorisé et enregistré.',
              'amount': amount,
            };
          } else if (status == 'requires_capture') {
            // If capture_method was manual, we'd need to send a separate capture request.
            // Since we use automatic, this is just a safety buffer.
            return {
              'success': true,
              'intent_id': intentId,
              'payment_confirmed': false,
              'message': 'Paiement autorisé. en attente de validation.',
              'amount': amount,
            };
          } else if (status == 'canceled') {
            throw Exception('Paiement annulé par le terminal.');
          } else if (status == 'requires_payment_method') {
            // Card was declined or reader timed out. Check reader details if possible.
            // Continue polling for a brief window in case card is retried, or abort if failed.
            final action = checkData['last_payment_error']?['message'];
            if (action != null) {
              throw Exception('Tentative de paiement échouée: $action');
            }
          }
        } else {
          onStatusUpdate?.call('Status poll warning: HTTP ${checkResponse.statusCode}');
        }
      }

      throw Exception('Carte non présentée, paiement annulé.');
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Erreur lors de la transaction.',
      };
    }
  }

  /// Realistic simulated terminal transaction for demonstration/offline purposes.
  Future<Map<String, dynamic>> _simulateTerminalPayment(
    double amount,
    void Function(String message)? onStatusUpdate,
  ) async {
    onStatusUpdate?.call('Simulation: Bootstrapping localized offline payment...');
    await Future.delayed(const Duration(milliseconds: 1000));
    
    onStatusUpdate?.call('Simulation: Activation du terminal...');
    await Future.delayed(const Duration(milliseconds: 1200));
    
    onStatusUpdate?.call('Simulation: Terminal prêt. présentez la carte...');
    await Future.delayed(const Duration(milliseconds: 1800));
    
    onStatusUpdate?.call('Simulation: Carte détectée! Vérification en cours...');
    await Future.delayed(const Duration(milliseconds: 1500));
    
    onStatusUpdate?.call('Simulation: Enregistrement du paiement ($amount)...');
    await Future.delayed(const Duration(milliseconds: 800));

    return {
      'success': true,
      'intent_id': 'pi_mock_${DateTime.now().millisecondsSinceEpoch}',
      'message': 'Simulation: Paiement approuvé ;) (Mode hors ligne).',
      'amount': amount,
    };
  }
}
