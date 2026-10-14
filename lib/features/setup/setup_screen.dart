/// setup_screen.dart
///
/// This screen collects the initial terminal configurations, including:
/// 1. Interactive Company Logo Upload using the image_picker package.
/// 2. Stripe Secret Key.
/// 3. Stripe Terminal ID.
/// 4. Sandbox/Simulator Toggle to test the client offline or in demo environments.
/// All configurations are saved securely via StorageService, and the user is routed
/// to the checkout dashboard.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../services/storage_service.dart';
import '../../services/logo_service.dart';
import '../../services/sumup_service.dart';
import '../payment/payment_screen.dart';
import '../colorpicker/colorpicker_dialog.dart';


class SetupScreen extends StatefulWidget {
  final StorageService storageService;
  final SumupService sumupService;

  const SetupScreen({
    Key? key,
    required this.storageService,
    required this.sumupService,
  }) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sumupMerchantCodeController = TextEditingController();
  final _sumupApiKeyController = TextEditingController();
  final _sumupAppIdController = TextEditingController();
  final _sumupAfKeyController = TextEditingController();
  final _sumupPairingCodeController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _terminalIdController = TextEditingController();
  final _associationNameController = TextEditingController();
  final _shortTextController = TextEditingController();
  
  Uint8List? _logoBytes;
  Uint8List? _originalLogoBytes;
  bool _isRemovingBackground = false;
  final _logoService = LogoService();
  final _translationController = TextEditingController();
  bool _isMockMode = false;
  bool _isTestMode = false;
  bool _isStripe = false;
  bool _isLoading = false;
  Color _amountButtonColor = const Color(0xFFC9A55C);
  Color _customButtonColor = const Color(0xFF757479);
  final Map<String, Color> _textColors = {};
  final Map<String, double> _textSizes = {};
  final Map<String, String> _textFonts = {};
  Color? _brandColor = const Color(0xFFEDEDED);

  @override
  void initState() {
    super.initState();
    _loadExistingConfigurations();
  }

  /// Prefills any existing settings if we are modifying credentials.
  Future<void> _loadExistingConfigurations() async {
    final sumupMerchantCode = await widget.storageService.getSumupMerchantCode();
    final sumupApiKey = await widget.storageService.getSumupApiKey();
    final sumupAfKey = await widget.storageService.getSumupAfKey();
    final sumupAppId = await widget.storageService.getSumupAppId();
    final sumupPairingCode = await widget.storageService.getSumupPairingCode();
    final secret = await widget.storageService.getStripeSecretKey();
    final terminal = await widget.storageService.getTerminalId();
    final logoPath = widget.storageService.getLogoPath();
    var logoBytes = widget.storageService.getLogoBytes();
    if (logoBytes == null && !kIsWeb && logoPath != null) {
      try { logoBytes = await File(logoPath).readAsBytes(); } catch (_) {}
    }
    if (!mounted) return;
    final isMock = widget.storageService.isMockMode();
    final isTest = widget.storageService.isTestMode();
    final isStripe = widget.storageService.isStripe();
    final associationName = widget.storageService.getAssociationName();
    final shortText = widget.storageService.getShortText();

    setState(() {
      _sumupApiKeyController.text = sumupApiKey ?? '';
      _sumupAppIdController.text = sumupAppId ?? '';
      _sumupAfKeyController.text = sumupAfKey ?? '';
      _sumupMerchantCodeController.text = sumupMerchantCode ?? '';
      _sumupPairingCodeController.text = sumupPairingCode ?? '';
      _secretKeyController.text = secret ?? '';
      _terminalIdController.text = terminal ?? '';
      _associationNameController.text = associationName;
      _shortTextController.text = shortText;
      _translationController.text = widget.storageService.getTranslationText();
      _isMockMode = isMock;
      _isTestMode = isTest;
      _isStripe = isStripe;
      _brandColor = widget.storageService.getBrandColor() == null ?const Color(0xFFEDEDED) : Color(widget.storageService.getBrandColor()!);
      _logoBytes = logoBytes;
      _amountButtonColor = Color(widget.storageService.getDonationButtonColor(false));
      _customButtonColor = Color(widget.storageService.getDonationButtonColor(true));
      for (final section in ['main', 'translation', 'association']) {
        _textColors[section] = Color(widget.storageService.getTextColor(section));
        _textSizes[section] = widget.storageService.getTextSize(section);
        _textFonts[section] = widget.storageService.getTextFont(section);
      }
    });
  }

  Future<void> _exportAppearance() async {
    final text = widget.storageService.exportAppearance();
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Copier la configuration visuelle'),
      content: const Text('Copiez la configuration, puis collez-la sur la nouvelle borne avec « Importer ». Les clés de paiement ne sont pas incluses. Seuls les réglages déjà enregistrés sont exportés.'),
      actions: [TextButton(onPressed: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) Navigator.pop(context);
      }, child: const Text('Copier'))],
    ));
  }

  Future<void> _importAppearance() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Importer la configuration visuelle'),
      content: TextField(controller: controller, maxLines: 6,
        decoration: const InputDecoration(hintText: 'Collez ici la configuration copiée depuis la première borne')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Importer')),
      ],
    ));
    // The dialog route may still be animating; let its field dispose itself first.
    if (text == null || !mounted) return;
    try {
      await widget.storageService.importAppearance(text);
      await _loadExistingConfigurations();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration visuelle importée.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration invalide : vérifiez le texte copié.')));
    }
  }

  Widget _buttonColorSetting(String label, bool custom) {
    final color = custom ? _customButtonColor : _amountButtonColor;
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Material(
      color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12),
      child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () async {
        final selected = await showColorPickerDialog(context: context, initialColor: color);
        if (selected != null && mounted) setState(() {
          if (custom) { _customButtonColor = selected; } else { _amountButtonColor = selected; }
        });
      }, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: color,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12))),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 18))),
        const Icon(Icons.chevron_right, color: Colors.black45),
      ]))),
    ));
  }

  Widget _textAppearance(String section) {
    final color = _textColors[section] ?? Color(widget.storageService.getTextColor(section));
    final size = _textSizes[section] ?? widget.storageService.getTextSize(section);
    final font = _textFonts[section] ?? widget.storageService.getTextFont(section);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Material(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final selected = await showColorPickerDialog(context: context, initialColor: color);
              if (selected != null && mounted) setState(() => _textColors[section] = selected);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12))),
                const SizedBox(width: 14),
                const Expanded(child: Text('Couleur', style: TextStyle(fontSize: 18))),
                Text('#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  style: const TextStyle(fontSize: 15, color: Colors.black54)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.black45),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: font,
          decoration: const InputDecoration(labelText: 'Police'),
          items: [
            DropdownMenuItem(value: 'Amiri', child: Text('Amiri', style: const TextStyle(fontFamily: 'Amiri', fontSize: 18))),
            DropdownMenuItem(value: 'ReemKufi', child: Text('Reem Kufi', style: const TextStyle(fontFamily: 'ReemKufi', fontSize: 18))),
            DropdownMenuItem(value: 'Roboto', child: Text('Sans sérif', style: const TextStyle(fontFamily: 'Roboto', fontSize: 18))),
            DropdownMenuItem(value: 'Cairo', child: Text('Cairo', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18))),
            DropdownMenuItem(value: 'Tajawal', child: Text('Tajawal', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18))),
            DropdownMenuItem(value: 'Almarai', child: Text('Almarai', style: const TextStyle(fontFamily: 'Almarai', fontSize: 18))),
            DropdownMenuItem(value: 'NotoSansArabic', child: Text('Noto Sans Arabic', style: const TextStyle(fontFamily: 'NotoSansArabic', fontSize: 18))),
            DropdownMenuItem(value: 'NotoNaskhArabic', child: Text('Noto Naskh Arabic', style: const TextStyle(fontFamily: 'NotoNaskhArabic', fontSize: 18))),
            DropdownMenuItem(value: 'Lateef', child: Text('Lateef', style: const TextStyle(fontFamily: 'Lateef', fontSize: 18))),
            DropdownMenuItem(value: 'ScheherazadeNew', child: Text('Scheherazade New', style: const TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 18))),
            DropdownMenuItem(value: 'ElMessiri', child: Text('El Messiri', style: const TextStyle(fontFamily: 'ElMessiri', fontSize: 18))),
            DropdownMenuItem(value: 'Inter', child: Text('Inter', style: const TextStyle(fontFamily: 'Inter', fontSize: 18))),
            DropdownMenuItem(value: 'Lato', child: Text('Lato', style: const TextStyle(fontFamily: 'Lato', fontSize: 18))),
            DropdownMenuItem(value: 'Montserrat', child: Text('Montserrat', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 18))),
            DropdownMenuItem(value: 'OpenSans', child: Text('Open Sans', style: const TextStyle(fontFamily: 'OpenSans', fontSize: 18))),
            DropdownMenuItem(value: 'Nunito', child: Text('Nunito', style: const TextStyle(fontFamily: 'Nunito', fontSize: 18))),
            DropdownMenuItem(value: 'Poppins', child: Text('Poppins', style: const TextStyle(fontFamily: 'Poppins', fontSize: 18))),
            DropdownMenuItem(value: 'Raleway', child: Text('Raleway', style: const TextStyle(fontFamily: 'Raleway', fontSize: 18))),
            DropdownMenuItem(value: 'DMSans', child: Text('DM Sans', style: const TextStyle(fontFamily: 'DMSans', fontSize: 18))),
            DropdownMenuItem(value: 'Manrope', child: Text('Manrope', style: const TextStyle(fontFamily: 'Manrope', fontSize: 18))),
            DropdownMenuItem(value: 'Rubik', child: Text('Rubik', style: const TextStyle(fontFamily: 'Rubik', fontSize: 18))),
          ],
          onChanged: (value) { if (value != null) setState(() => _textFonts[section] = value); },
        ),
        const SizedBox(height: 8),
        Text('Taille : ${size.round()} px'),
        Slider(value: size.clamp(12, 72), min: 12, max: 72, divisions: 60,
          label: '${size.round()} px', onChanged: (value) => setState(() => _textSizes[section] = value)),
      ]),
    );
  }

  /// Triggers the device's file picker or gallery to choose a brand logo.
  Future<void> _pickLogo() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _originalLogoBytes = bytes;
          _isRemovingBackground = true;
        });
        try {
          final transparent = await _logoService.removeBackground(bytes);
          if (!mounted) return;
          setState(() => _logoBytes = transparent);
        } catch (_) {
          if (!mounted) return;
          setState(() => _logoBytes = bytes);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Détourage indisponible : logo original conservé. Vérifiez que le service local est lancé.'),
          ));
        } finally {
          if (mounted) setState(() => _isRemovingBackground = false);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select image: $e')),
      );
    }
  }

  // Try Pair Sumup reader and save reader id api key & merchant code
  // Future<void> _handleSumupPairUp() async{
  //   return;
  // }

  /// Persists credentials and transitions state safely.
  Future<void> _handleSubmit() async {
    // If mock mode is selected, we bypass strict field validation
    if (!_isMockMode && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Process Logo saving if provided
      if (_logoBytes != null) {
        await widget.storageService.saveLogoBytes(_logoBytes!);
      } else {
        await widget.storageService.clearLogo();
      }

      await widget.storageService.setDonationButtonColor(false, _amountButtonColor.toARGB32());
      await widget.storageService.setDonationButtonColor(true, _customButtonColor.toARGB32());

      // 2. Save Mock Mode
      await widget.storageService.setMockMode(_isMockMode);
      // 2. Save Payment Mode
      await widget.storageService.setIsStripe(_isStripe);
      // 2. Save Test Mode
      await widget.storageService.setTestMode(_isTestMode);

      // Save custom association fields
      await widget.storageService.setAssociationName(_associationNameController.text.trim());
      await widget.storageService.setShortText(_shortTextController.text.trim());
      await widget.storageService.setTranslationText(_translationController.text.trim());
      for (final section in ['main', 'translation', 'association']) {
        await widget.storageService.setTextAppearance(section,
          (_textColors[section] ?? Color(widget.storageService.getTextColor(section))).toARGB32(),
          _textSizes[section] ?? widget.storageService.getTextSize(section),
          _textFonts[section] ?? widget.storageService.getTextFont(section));
      }

      // 3. Save payment provider details
      if (!_isMockMode) {
        if(_isStripe){
          //stripe
          await widget.storageService.setStripeSecretKey(_secretKeyController.text.trim());
          await widget.storageService.setTerminalId(_terminalIdController.text.trim());
        }else{
          final pairingCode = await widget.storageService.getSumupPairingCode();
          //sumup
          if(_sumupPairingCodeController.text.trim() != pairingCode.toString()){
            try{
              final String? readerId = await widget.sumupService.pairSumupSolo(
                _sumupMerchantCodeController.text.trim(),
                _sumupApiKeyController.text.trim(),
                _sumupPairingCodeController.text.trim()
              );

              if (readerId == null){
                throw Exception('Impossible de coupler le terminal...');
              }

              await widget.storageService.setSumupReaderId(readerId);
            }catch(e){
              print('error while pairing sumup: $e');
              return;
            }
          }

          await widget.storageService.setSumupApiKey(_sumupApiKeyController.text.trim());
          await widget.storageService.setSumupMerchantCode(_sumupMerchantCodeController.text.trim());
          await widget.storageService.setSumupAppId(_sumupAppIdController.text.trim());
          await widget.storageService.setSumupAfKey(_sumupAfKeyController.text.trim());
          await widget.storageService.setSumupPairingCode(_sumupPairingCodeController.text.trim());

        }

      } else {
        // Clear old production credentials in mock state
        //sumup
        await widget.storageService.setSumupApiKey('');
        await widget.storageService.setSumupMerchantCode('');
        await widget.storageService.setSumupPairingCode('');

        //stripe
        await widget.storageService.setStripeSecretKey('');
        await widget.storageService.setTerminalId('');
      }
      
      

      // 4. Success Transition
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentScreen(storageService: widget.storageService, sumupService: widget.sumupService),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppConstants.error,
            content: Text('Impossible d\'enregistrer les paramètres: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _secretKeyController.dispose();
    _terminalIdController.dispose();
    _associationNameController.dispose();
    _shortTextController.dispose();
    _translationController.dispose();
    _logoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontSizeFactor: 1.2),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          labelStyle: const TextStyle(fontSize: 18),
          hintStyle: const TextStyle(fontSize: 17),
          helperStyle: const TextStyle(fontSize: 15),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(textStyle: const TextStyle(fontSize: 18))),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: const TextStyle(fontSize: 18))),
      ),
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFEDEDED),
          image: DecorationImage(
            image: AssetImage('assets/legacy/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Header Block ---
                        const Text(
                          'Configurez votre borne de paiement',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.8,
                            color: AppConstants.foreground,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        const Text(
                          'Saisissez les information de votre compte et de votre terminal Stripe pour commencer.',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppConstants.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 32.0),

                        // --- Image/Logo Picker Section ---
                        const Text(
                          'Logo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppConstants.foreground),
                        ),
                        const SizedBox(height: 8.0),
                        Row(
                          children: [
                            Container(
                              height: 80,
                              width: 80,
                              decoration: BoxDecoration(
                                color: AppConstants.secondary,
                                border: Border.all(color: AppConstants.border, width: 1.0),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: _logoBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.memory(_logoBytes!, fit: BoxFit.contain),
                                    )
                                  : const Icon(
                                      Icons.business,
                                      color: AppConstants.mutedForeground,
                                      size: 32,
                                    ),
                            ),
                            const SizedBox(width: 16.0),
                            OutlinedButton.icon(
                              onPressed: _isRemovingBackground ? null : _pickLogo,
                              icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                              label: Text(_isRemovingBackground ? 'Détourage en cours…' : 'Choisissez votre logo'),
                            ),
                            if (_logoBytes != null) ...[
                              const SizedBox(width: 8.0),
                              TextButton(
                                onPressed: () => setState(() { _logoBytes = null; _originalLogoBytes = null; }),
                                child: const Text('Retirer', style: TextStyle(color: Colors.red)),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 24.0),

                        if (_isRemovingBackground) const Padding(
                          padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator()),
                        if (_originalLogoBytes != null && !_isRemovingBackground) Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextButton.icon(
                            icon: const Icon(Icons.restore),
                            label: const Text('Garder le logo original'),
                            onPressed: () => setState(() => _logoBytes = _originalLogoBytes),
                          ),
                        ),
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          OutlinedButton(onPressed: _exportAppearance, child: const Text('Exporter les réglages visuels')),
                          OutlinedButton(onPressed: _importAppearance, child: const Text('Importer les réglages visuels')),
                        ]),
                        const SizedBox(height: 24),
                        const Text('Couleurs des boutons', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buttonColorSetting('Montants : 5, 10, 20, 30, 50 €', false),
                        _buttonColorSetting('Autre montant', true),
                        TextButton(onPressed: () => setState(() {
                          _amountButtonColor = const Color(0xFFC9A55C);
                          _customButtonColor = const Color(0xFF757479);
                        }), child: const Text('Rétablir les couleurs de base')),
                        const SizedBox(height: 24),
                        // --- Association Customization Fields ---
                        const Text(
                          'Nom de l\'association / Établissement',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppConstants.foreground),
                        ),
                        const SizedBox(height: 8.0),
                        TextFormField(
                          controller: _associationNameController,
                          decoration: const InputDecoration(
                            hintText: 'Ex: Association Al-Salam',
                            prefixIcon: Icon(Icons.favorite_outline, size: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter the association name';
                            }
                            return null;
                          },
                        ),
                        _textAppearance('association'),
                        const SizedBox(height: 20.0),

                        const Text(
                          'Texte principal / Verset / Appel aux dons',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppConstants.foreground),
                        ),
                        
                        const SizedBox(height: 8.0),
                        TextFormField(
                          controller: _shortTextController,
                          textDirection: RegExp(r'[\u0600-\u06FF]').hasMatch(_shortTextController.text) ? TextDirection.rtl : TextDirection.ltr,
                          textAlign: TextAlign.start,
                          onChanged: (_) => setState(() {}),
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Ex: Soutenez nos actions. Chaque don compte.',
                            prefixIcon: Icon(Icons.description_outlined, size: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Saisissez votre texte d\'appel aux dons';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24.0),

                        _textAppearance('main'),
                        const Text('Traduction / Texte complémentaire (facultatif)'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _translationController,
                          maxLines: 3,
                          decoration: const InputDecoration(hintText: 'Traduction du verset ou précision sur votre appel aux dons', helperText: 'Entrée permet de choisir vos retours à la ligne.'),
                        ),
                        const SizedBox(height: 24),

                        _textAppearance('translation'),
                        // --- Sandbox Simulation Toggle ---
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          decoration: BoxDecoration(
                            color: AppConstants.secondary,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: AppConstants.border, width: 1.0),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Mock Reader / Sandbox',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Simule les paiements sans accès au réseau.',
                                      style: TextStyle(fontSize: 16, color: AppConstants.mutedForeground),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isMockMode,
                                activeColor: AppConstants.primary,
                                onChanged: (value) {
                                  setState(() {
                                    _isMockMode = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24.0),

                        // --- Dynamic Form Fields ---
                        if (!_isMockMode) ...[
                          // --- Is Stripe or Sumup Toggle ---
                          // Container(
                          //   padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          //   decoration: BoxDecoration(
                          //     color: const Color.fromARGB(255, 57, 61, 60),
                          //     borderRadius: BorderRadius.circular(8.0),
                          //     border: Border.all(color: AppConstants.border, width: 1.0),
                          //   ),
                          //   child: Row(
                          //     children: [
                          //       Expanded(
                          //         child: Column(
                          //           crossAxisAlignment: CrossAxisAlignment.start,
                          //           children: [
                          //             Text(
                          //               'Service de paiement',
                          //               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.accent),
                          //             ),
                          //             SizedBox(
                          //               height: 10.0,
                          //             ),
                          //             Image.asset(
                          //               _isStripe ? 'assets/hd-stripe-white-logo.png' : 'assets/Sumup_logo-white.png',
                          //               height: 30.0,
                          //             ),
                          //             // Text(
                          //             //   _isStripe ? 'Stripe' : 'Sumup',
                          //             //   style: TextStyle(fontSize: 18, color: AppConstants.accent, fontStyle: FontStyle.italic),
                          //             // ),
                          //           ],
                          //         ),
                          //       ),
                          //       Switch(
                          //         value: _isStripe,
                          //         activeColor: AppConstants.secondary,
                          //         onChanged: (value) {
                          //           setState(() {
                          //             _isStripe = value;
                          //           });
                          //         },
                          //       ),
                          //     ],
                          //   ),
                          // ),
                          // const SizedBox(height: 24.0),
                          
                          // --- Integration test Toggle ---
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 101, 232, 188),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: AppConstants.border, width: 1.0),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Mode test',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.accentForeground),
                                      ),
                                      Text(
                                        'Testez votre integration avec un terminal de test.',
                                        style: TextStyle(fontSize: 16, color: AppConstants.accentForeground),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _isTestMode,
                                  activeColor: AppConstants.secondary,
                                  onChanged: (value) {
                                    setState(() {
                                      _isTestMode = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24.0),

                          DefaultTabController(
                            length: 2,
                            initialIndex: _isStripe ? 0 : 1,
                            child: 
                              Column(
                                children:<Widget>[
                                  TabBar(
                                    indicatorWeight: 10.0,
                                    indicatorColor: Color.lerp(_brandColor,Colors.black,0.2),
                                    onTap: (index) {
                                      if (index == 0) {
                                        setState(() {
                                          _isStripe = true;
                                        });
                                      } else if (index == 1) {
                                        setState(() {
                                          _isStripe = false;
                                        });
                                      }
                                    },
                                    tabs: [
                                      Tab(
                                        child: Image.asset(
                                          'assets/hd-stripe-white-logo.png',
                                          color: Color.lerp(_brandColor,Colors.black,0.2),
                                          height: 30.0,
                                        ),
                                      ),
                                      Tab(
                                        child:Image.asset(
                                          'assets/Sumup_logo-white.png',
                                          color: Color.lerp(_brandColor,Colors.black,0.2),
                                          height: 30.0,
                                        ),
                                      )
                                    ]
                                  ),
                                  SizedBox(
                                    height: _isStripe ? 250: 550 /*MediaQuery.of(context).size.height * 0.3*/,
                                    child:TabBarView(
                                      children: [
                                      //--- stripe config form ---
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children:[
                                          SizedBox(height: 30.0),
                                          Text(
                                            'Stripe Secret API Key',
                                            textAlign: TextAlign.start,
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppConstants.foreground),
                                          ),
                                          SizedBox(height: 8.0),
                                          TextFormField(
                                            controller: _secretKeyController,
                                            obscureText: true,
                                            decoration:  InputDecoration(
                                              hintText: 'sk_...',
                                              prefixIcon: Icon(Icons.vpn_key_outlined, size: 16),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Saisissez votre clé Stripe';
                                              }
                                              if (!value.startsWith('sk_')) {
                                                return 'Saisissez une clé valide qui commence par sk_';
                                              }
                                              return null;
                                            },
                                          ),
                                          SizedBox(height: 20.0),

                                          // Stripe Terminal ID
                                          Text(
                                            'Stripe Terminal Reader ID',
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppConstants.foreground),
                                          ),

                                          SizedBox(height: 8.0),
                                          TextFormField(
                                            controller: _terminalIdController,
                                            decoration: const InputDecoration(
                                              hintText: 'tmr_...',
                                              prefixIcon: Icon(Icons.chrome_reader_mode_outlined, size: 16),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Saisissez l\id de votre terminal Stripe';
                                              }
                                              return null;
                                            },
                                          ),
                                          
                                          SizedBox(height: 32.0),
                                        ]
                                      ),

                                      //--- Sumup config form ---
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children:[
                                          SizedBox(height: 30.0),
                                          Text(
                                            'Code commerçant Sumup',
                                            textAlign: TextAlign.start,
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppConstants.foreground),
                                          ),
                                          SizedBox(height: 8.0),
                                          TextFormField(
                                            controller: _sumupMerchantCodeController,
                                            // obscureText: true,
                                            decoration:  InputDecoration(
                                              hintText: 'code commerçant...',
                                              prefixIcon: Icon(Icons.store, size: 16),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Saisissez votre code commerçant';
                                              }
                                              return null;
                                            },
                                          ),
                                          SizedBox(height: 20.0),
                                          Text(
                                            'Sumup API Key',
                                            textAlign: TextAlign.start,
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppConstants.foreground),
                                          ),
                                          SizedBox(height: 8.0),
                                          TextFormField(
                                            controller: _sumupApiKeyController,
                                            obscureText: true,
                                            decoration:  InputDecoration(
                                              hintText: 'sup_sk...',
                                              prefixIcon: Icon(Icons.vpn_key_outlined, size: 16),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Saisissez votre clé Sumup';
                                              }
                                              if (!value.startsWith('sup_sk_')) {
                                                return 'Saisissez une clé valide';
                                              }
                                              return null;
                                            },
                                          ),
                                          SizedBox(height: 20.0),
                                          Text(
                                            'Identifiant d\'application Sumup',
                                            textAlign: TextAlign.start,
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppConstants.foreground),
                                          ),
                                          SizedBox(height: 8.0),
                                          TextFormField(
                                            controller: _sumupAppIdController,
                                            decoration:  InputDecoration(
                                              hintText: 'id application...',
                                              prefixIcon: Icon(Icons.vpn_key_outlined, size: 16),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Saisissez votre identifiant d\'application';
                                              }
                                              return null;
                                            },
                                          ),
                                          SizedBox(height: 20.0),
                                          Text(
                                            'Clé d\'affiliation Sumup',
                                            textAlign: TextAlign.start,
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppConstants.foreground),
                                          ),
                                          SizedBox(height: 8.0),
                                          TextFormField(
                                            controller: _sumupAfKeyController,
                                            obscureText: true,
                                            decoration:  InputDecoration(
                                              hintText: 'sup_afk...',
                                              prefixIcon: Icon(Icons.vpn_key_outlined, size: 16),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Saisissez votre clé Sumup';
                                              }
                                              if (!value.startsWith('sup_afk_')) {
                                                return 'Saisissez une clé valide';
                                              }
                                              return null;
                                            },
                                          ),
                                          SizedBox(height: 20.0),

                                          // Stripe Terminal ID
                                          Text(
                                            'Paircode Sumup',
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppConstants.foreground),
                                          ),

                                          SizedBox(height: 8.0),
                                          TextFormField(
                                            controller: _sumupPairingCodeController,
                                            decoration: const InputDecoration(
                                              hintText: 'pairng code...',
                                              prefixIcon: Icon(Icons.add_link, size: 16),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Saisissez le pair code généré depuis votre terminal Sumup';
                                              }
                                              return null;
                                            },
                                          ),
                                          SizedBox(height: 32.0),
                                          
                                        ]
                                      ),
                                        
                                      ]
                                    ),
                                  )
                                ]
                              )
                          ),
                        
                        ] else ...[
                          const SizedBox(height: 16.0),
                        ],

                        // --- Submit Action Button ---
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading || _isRemovingBackground ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBDBDBD),
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Initialiser la borne'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
