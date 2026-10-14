/// storage_service.dart
///
/// This service handles all local persistence operations. It utilizes:
/// - flutter_secure_storage for storing credentials (Stripe Secret API Key and Terminal ID) safely.
/// - shared_preferences for non-sensitive configurations (like the stored logo path).
/// - path_provider & dart:io to copy and persist the custom logo file locally.
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageService {
  // --- Secure Storage Keys ---
  static const String _keySumupApiKey = 'sumup_api_key';
  static const String _keySumupAppId = 'sumup_app_id';
  static const String _keySumupAfKey = 'sumup_affiliation_key';
  static const String _keySumupMerchantCode = 'sumup_merchant_code';
  static const String _keySumupPairingCode = 'sumup_pairing_code';
  static const String _keySumupReaderId = 'sumup_reader_id';
  static const String _keyStripeSecret = 'stripe_secret_key';
  static const String _keyTerminalId = 'stripe_terminal_id';
  
  // --- Shared Preferences Keys ---
  static const String _keyLogoPath = 'company_logo_path';
  static const String _keyBrandColor = 'brand_color';
  static const String _keyIsMockMode = 'pos_is_mock_mode';
  static const String _keyIsTestMode = 'pos_is_test_mode';
  static const String _keyIsStripe = 'pos_is_stripe';
  static const String _keyAssociationName = 'association_name';
  static const String _keyShortText = 'short_text';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  StorageService({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
  })  : _secureStorage = secureStorage,
        _prefs = prefs;

  /// Factory initializer to resolve dependencies asynchronously before application startup.
  static Future<StorageService> initialize() async {
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    final prefs = await SharedPreferences.getInstance();
    // Adopt the new grey default once, including previously saved preview colours.
    // Later choices made in the colour picker remain saved normally.
    if (prefs.getBool('grey_theme_default_applied') != true) {
      await prefs.setInt(_keyBrandColor, 0xFFEDEDED);
      await prefs.setBool('grey_theme_default_applied', true);
    }
    return StorageService(secureStorage: secureStorage, prefs: prefs);
  }


  // --- Sumup Credentials Handling ---
  /// Reads the stored Sumup Merchant Code securely.
  Future<String?> getSumupMerchantCode() async {
    return await _secureStorage.read(key: _keySumupMerchantCode);
  }
  /// Writes the Sumup Merchant Code securely.
  Future<void> setSumupMerchantCode(String merchantCode) async {
    await _secureStorage.write(key: _keySumupMerchantCode, value: merchantCode);
  }
  /// Reads the stored Sumup Api Key securely.
  Future<String?> getSumupApiKey() async {
    return await _secureStorage.read(key: _keySumupApiKey);
  }
  /// Writes the Sumup Api Key securely.
  Future<void> setSumupApiKey(String apiKey) async {
    await _secureStorage.write(key: _keySumupApiKey, value: apiKey);
  }
  /// Reads the stored Sumup App Id securely.
  Future<String?> getSumupAppId() async {
    return await _secureStorage.read(key: _keySumupAppId);
  }
  /// Writes the Sumup Api Key securely.
  Future<void> setSumupAppId(String id) async {
    await _secureStorage.write(key: _keySumupAppId, value: id);
  }
  /// Reads the stored Sumup Api Key securely.
  Future<String?> getSumupAfKey() async {
    return await _secureStorage.read(key: _keySumupAfKey);
  }
  /// Writes the Sumup Api Key securely.
  Future<void> setSumupAfKey(String key) async {
    await _secureStorage.write(key: _keySumupAfKey, value: key);
  }
  /// Reads the stored Sumup Pairign Code securely.
  Future<String?> getSumupPairingCode() async {
    return await _secureStorage.read(key: _keySumupPairingCode);
  }
  /// Writes the Sumup Api Key securely.
  Future<void> setSumupPairingCode(String pairingCode) async {
    await _secureStorage.write(key: _keySumupPairingCode, value: pairingCode);
  }
  /// Reads the stored Sumup Pairign Code securely.
  Future<String?> getSumupReaderId() async {
    return await _secureStorage.read(key: _keySumupReaderId);
  }
  /// Writes the Sumup Api Key securely.
  Future<void> setSumupReaderId(String id) async {
    await _secureStorage.write(key: _keySumupReaderId, value: id);
  }


  // --- Stripe Credentials Handling ---
  /// Reads the stored Stripe Secret Key securely.
  Future<String?> getStripeSecretKey() async {
    return await _secureStorage.read(key: _keyStripeSecret);
  }

  /// Writes the Stripe Secret Key securely.
  Future<void> setStripeSecretKey(String secretKey) async {
    await _secureStorage.write(key: _keyStripeSecret, value: secretKey);
  }

  /// Reads the stored Stripe Terminal Reader ID securely.
  Future<String?> getTerminalId() async {
    return await _secureStorage.read(key: _keyTerminalId);
  }

  /// Writes the Stripe Terminal Reader ID securely.
  Future<void> setTerminalId(String terminalId) async {
    await _secureStorage.write(key: _keyTerminalId, value: terminalId);
  }

  // --- Brand Color operations ---
  int? getBrandColor(){
    return _prefs.getInt(_keyBrandColor);
  }

  Future<bool> setBrandColor(int colorValue){
    return _prefs.setInt(_keyBrandColor, colorValue);
  }

  // --- Company Logo Operations ---

  Uint8List? getLogoBytes() {
    final encoded = _prefs.getString('company_logo_bytes');
    return encoded == null ? null : base64Decode(encoded);
  }

  Future<void> saveLogoBytes(Uint8List bytes) async {
    await _prefs.setString('company_logo_bytes', base64Encode(bytes));
    await _prefs.remove(_keyLogoPath);
  }

  static const _appearanceKeys = <String>[
    'association_name', 'short_text', 'translation_text', 'company_logo_bytes',
    'amount_buttons_color', 'custom_button_color',
    'text_main_color', 'text_main_size', 'text_main_font',
    'text_translation_color', 'text_translation_size', 'text_translation_font',
    'text_association_color', 'text_association_size', 'text_association_font',
  ];

  String exportAppearance() => jsonEncode({
    'format': 'borne-appearance-v1',
    'settings': {for (final key in _appearanceKeys) if (_prefs.containsKey(key)) key: _prefs.get(key)},
  });

  Future<void> importAppearance(String text) async {
    final data = jsonDecode(text);
    if (data is! Map || data['format'] != 'borne-appearance-v1' || data['settings'] is! Map) {
      throw const FormatException('Configuration invalide.');
    }
    final settings = data['settings'] as Map;
    for (final key in _appearanceKeys) {
      final value = settings[key];
      if (value == null) continue;
      if (key.endsWith('_size')) {
        if (value is! num || value < 12 || value > 72) throw const FormatException('Taille invalide.');
      } else if (key.endsWith('_color')) {
        if (value is! int || value < 0 || value > 0xFFFFFFFF) throw const FormatException('Couleur invalide.');
      } else if (value is! String) {
        throw const FormatException('Texte invalide.');
      }
      if (key == 'company_logo_bytes') base64Decode(value as String);
    }
    for (final key in _appearanceKeys) {
      final value = settings[key];
      if (value == null) continue;
      if (key.endsWith('_size')) { await _prefs.setDouble(key, (value as num).toDouble()); }
      else if (value is int) { await _prefs.setInt(key, value); }
      else { await _prefs.setString(key, value as String); }
    }
  }

  int getDonationButtonColor(bool custom) => _prefs.getInt(custom ? 'custom_button_color' : 'amount_buttons_color') ??
      (custom ? 0xFF757479 : 0xFFC9A55C);

  Future<void> setDonationButtonColor(bool custom, int value) async {
    await _prefs.setInt(custom ? 'custom_button_color' : 'amount_buttons_color', value);
  }

  int getTextColor(String section) => _prefs.getInt('text_${section}_color') ??
      (section == 'main' ? 0xFFC9A55C : 0xFF757479);

  double getTextSize(String section) => _prefs.getDouble('text_${section}_size') ??
      (section == 'main' ? 36 : section == 'translation' ? 24 : 40);

  String getTextFont(String section) => _prefs.getString('text_${section}_font') ??
      (section == 'main' ? 'Amiri' : 'ReemKufi');

  Future<void> setTextAppearance(String section, int color, double size, String font) async {
    await _prefs.setInt('text_${section}_color', color);
    await _prefs.setDouble('text_${section}_size', size);
    await _prefs.setString('text_${section}_font', font);
  }

  String getTranslationText() => _prefs.getString('translation_text') ??
      '« Si vous faites à Allah un prêt sincère, Il le multipliera pour vous et vous pardonnera. Allah cependant est très Reconnaissant et Indulgent. » [At-Taghaabun : 17]';

  Future<void> setTranslationText(String value) async {
    await _prefs.setString('translation_text', value);
  }

  /// Reads the saved company logo local file path.
  String? getLogoPath() {
    return _prefs.getString(_keyLogoPath);
  }

  /// Saves a custom selected logo image into the app's local documents directory.
  /// This ensures the image is persisted on disk and won't be deleted as cache.
  Future<String> saveLogo(File sourceFile) async {
    try {
      final Directory docDir = await getApplicationDocumentsDirectory();
      final String fileExtension = p.extension(sourceFile.path);
      final String newFileName = 'company_logo_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final String destinationPath = p.join(docDir.path, newFileName);
      
      // Copy source file to permanent storage
      final File savedFile = await sourceFile.copy(destinationPath);
      
      // Save path to preferences
      await _prefs.setString(_keyLogoPath, savedFile.path);
      return savedFile.path;
    } catch (e) {
      throw Exception('Failed to save company logo locally: $e');
    }
  }

  /// Clears the saved logo path from memory.
  Future<void> clearLogo() async {
    await _prefs.remove('company_logo_bytes');
    await _prefs.remove(_keyLogoPath);
  }

  // --- Mock Mode Configuration ---

  /// Check if the POS is running in "Mock Reader / Sandbox" mode for demo purposes.
  bool isMockMode() {
    return _prefs.getBool(_keyIsMockMode) ?? false;
  }
  /// Check if the POS is running in "Integration test" mode for demo purposes.
  bool isTestMode() {
    return _prefs.getBool(_keyIsTestMode) ?? false;
  }

  /// Check if the payment will be handle through Stripe or Sumup.
  bool isStripe() {
    return _prefs.getBool(_keyIsStripe) ?? false;
  }

  /// Toggles mock reader simulation mode.
  Future<void> setMockMode(bool enabled) async {
    await _prefs.setBool(_keyIsMockMode, enabled);
  }
  /// Toggles test integration  mode.
  Future<void> setTestMode(bool enabled) async {
    await _prefs.setBool(_keyIsTestMode, enabled);
  }
  /// Toggles test integration  mode.
  Future<void> setIsStripe(bool enabled) async {
    await _prefs.setBool(_keyIsStripe, enabled);
  }

  // --- Association & Short Text Configuration ---

  /// Gets the stored Association Name, defaulting to "Association Al-Karam".
  String getAssociationName() {
    return _prefs.getString(_keyAssociationName) ?? 'Votre association';
  }

  /// Sets the stored Association Name.
  Future<void> setAssociationName(String value) async {
    await _prefs.setString(_keyAssociationName, value);
  }

  /// Gets the stored short text for calls to action, with default.
  String getShortText() {
    return _prefs.getString(_keyShortText) ?? 
        '﴿إِن تُقْرِضُوا اللَّهَ قَرْضًا حَسَنًا يُضَاعِفْهُ لَكُمْ وَيَغْفِرْ لَكُمْ ۚ وَاللَّهُ شَكُورٌ حَلِيمٌ﴾ [التغابن : ١٧]';
  }

  /// Sets the stored short text for calls to action.
  Future<void> setShortText(String value) async {
    await _prefs.setString(_keyShortText, value);
  }

  // --- Configuration Checks ---

  /// Determines if the application has been fully configured.
  /// If Stripe Secret and Terminal Reader ID exist (or if Mock Mode is enabled), returns true.
  Future<bool> isConfigured() async {
    if (isMockMode()) {
      return true;
    }
    if(isStripe()){
      final secret = await getStripeSecretKey();
      final terminal = await getTerminalId();
      return secret != null && secret.isNotEmpty && terminal != null && terminal.isNotEmpty;
    }else{
      final sumupReaderId = await getSumupReaderId();
      return sumupReaderId != null && sumupReaderId.isNotEmpty;

    }
  }

  /// Clears all local configurations to support re-entering setup details.
  Future<void> resetAll() async {
    await clearLogo();
    await _prefs.remove('translation_text');
    await _secureStorage.delete(key: _keyStripeSecret);
    await _secureStorage.delete(key: _keyTerminalId);
    await _prefs.remove(_keyLogoPath);
    await _prefs.remove(_keyIsMockMode);
    await _prefs.remove(_keyAssociationName);
    await _prefs.remove(_keyShortText);
  }
}
