/// main.dart
///
/// This is the primary bootstrapper and entry point of the Flutter application.
/// It asynchronously initializes core packages:
/// 1. WidgetsFlutterBinding to bind layout configurations
/// 2. SharedPreferences & SecureStorage inside StorageService to load state
/// 3. Evaluates if the POS is ready for transactions (has keys & reader credentials)
/// 4. Boots either the Setup Screen or Checkout Payment Screen based on setup status.
import 'dart:async';
import 'package:flutter/material.dart';
import 'services/logo_runtime.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'services/storage_service.dart';
import 'services/sumup_service.dart';
import 'features/setup/setup_screen.dart';
import 'features/payment/payment_screen.dart';

void main() async {
  // Ensure that Flutter widget interactions are fully bound and ready before async loading
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(startLocalLogoService());

  StorageService? storage;
  SumupService sumupService = new SumupService();
  bool isTerminalConfigured = false;

  try {
    // Asynchronously resolve local disk storage services (prefs + secure keys)
    storage = await StorageService.initialize();
    
    // Check if the business has already saved Stripe keys and reader bindings
    isTerminalConfigured = await storage.isConfigured();
  } catch (e) {
    debugPrint('Bootstrapper Error: Failed to resolve local storage drivers. $e');
  }

  // Run application with custom, Shadcn-style minimalist theme settings
  runApp(StripePOSApp(
    storageService: storage,
    initialScreen: storage == null
        ? const SizedBox.shrink()
        : isTerminalConfigured
        ? PaymentScreen(storageService: storage!, sumupService: sumupService)
        : SetupScreen(storageService: storage!, sumupService: sumupService),
  ));
}

class StripePOSApp extends StatelessWidget {
  final StorageService? storageService;
  final Widget initialScreen;

  const StripePOSApp({
    Key? key,
    required this.storageService,
    required this.initialScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Borne de dons',
      debugShowCheckedModeBanner: false,
      
      // Apply professional Shadcn visual theme custom specs
      theme: AppTheme.lightTheme,
      
      // Fallback screen in case storage initialization crashed
      home: storageService == null
          ? const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Fatal Initialization Error.\nFailed to mount local secure key storage driver.\nPlease restart or verify platform permissions.',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : initialScreen,
    );
  }
}
