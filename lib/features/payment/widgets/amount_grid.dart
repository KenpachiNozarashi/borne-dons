import 'package:flutter/material.dart';

const _gold = Color(0xFFC9A55C);
const _grey = Color(0xFF757479);

class AmountGrid extends StatelessWidget {
  final Function(double amount) onAmountSelected;
  final double buttonSize;
  final Color amountColor;
  final Color customColor;

  const AmountGrid({
    super.key,
    required this.buttonSize,
    required this.onAmountSelected,
    this.amountColor = _gold,
    this.customColor = _grey,
  });

  Future<void> _customAmount(BuildContext context) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _AmountDialog(amountColor: amountColor, customColor: customColor),
    );
    if (amount != null) onAmountSelected(amount);
  }

  @override
  Widget build(BuildContext context) {
    const amounts = [5.0, 10.0, 20.0, 30.0, 50.0];
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / 770).clamp(0.0, 1.0);
        final gap = 30.0 * scale;
        final height = buttonSize * scale;
        final amountFont = (96.0 * scale).clamp(0.1, height * 0.8);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: height,
          ),
          itemCount: amounts.length + 1,
          itemBuilder: (context, index) {
            final custom = index == amounts.length;
            return DonationButton(
              label: custom ? 'Autre\nmontant' : '${amounts[index].toInt()} €',
              grey: custom,
              baseColor: custom ? (customColor == _grey ? null : customColor) : (amountColor == _gold ? null : amountColor),
              fontSize: custom ? amountFont * 0.8 : amountFont,
              onTap: custom
                  ? () => _customAmount(context)
                  : () => onAmountSelected(amounts[index]),
            );
          },
        );
      },
    );
  }
}

class DonationButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool grey;
  final double fontSize;
  final Color? baseColor;
  final bool subtle;
  const DonationButton({required this.label, required this.onTap, this.grey = false, this.fontSize = 30, this.baseColor, this.subtle = false});

  @override
  State<DonationButton> createState() => _DonationButtonState();
}

class _DonationButtonState extends State<DonationButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = widget.onTap == null
      ? const [Color(0xFFCCCCCC), Color(0xFFBDBDBD), Color(0xFFAAAAAA)]
      : widget.baseColor != null
        ? [Color.lerp(widget.baseColor, Colors.white, _hovered ? 0.45 : 0.25)!,
           _hovered ? Color.lerp(widget.baseColor, Colors.white, 0.15)! : widget.baseColor!,
           Color.lerp(widget.baseColor, Colors.black, _hovered ? 0.3 : 0.2)!]
        : widget.grey
      ? (_hovered ? const [Color(0xFFBDBCBF), Color(0xFF868588), Color(0xFF474747)]
                  : const [Color(0xFF99989B), _grey, Color(0xFF5A5A5A)])
      : (_hovered ? const [Color(0xFFF1DFC4), Color(0xFFD2A860), Color(0xFF8F6A2C)]
                  : const [Color(0xFFE0C89B), _gold, Color(0xFFA08040)]);
    final base = widget.baseColor ?? _grey;
    final subtleColors = [
      Color.lerp(base, Colors.white, _hovered ? 0.12 : 0.05)!,
      _hovered ? Color.lerp(base, Colors.white, 0.06)! : base,
      Color.lerp(base, Colors.black, 0.08)!,
    ];
    final duration = Duration(milliseconds: widget.grey ? 300 : 200);
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) { if (widget.onTap != null) setState(() => _hovered = true); },
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: duration,
        child: AnimatedContainer(
          duration: duration,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: widget.subtle && widget.onTap != null
                ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: subtleColors, stops: const [0, 0.5, 1])
                : RadialGradient(radius: 0.8, colors: colors, stops: const [0, 0.5, 1]),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: widget.subtle ? (_hovered ? 0.16 : 0.1) : (_hovered ? 0.4 : 0.3)),
              blurRadius: widget.subtle ? 6 : (_hovered ? 15 : 10),
              offset: Offset(0, widget.subtle ? 3 : (_hovered ? 8 : 5)),
            )],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: Center(child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(widget.label, textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: widget.fontSize, fontWeight: FontWeight.bold)),
              )),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountDialog extends StatefulWidget {
  final Color amountColor;
  final Color customColor;
  const _AmountDialog({required this.amountColor, required this.customColor});
  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  String _value = '';
  double? get _amount => double.tryParse(_value);

  void _key(String key) {
    setState(() {
      if (key == 'C') {
        _value = '';
      } else if (key == '⌫') {
        if (_value.isNotEmpty) _value = _value.substring(0, _value.length - 1);
      } else if (key == ',') {
        if (!_value.contains('.')) _value = '${_value.isEmpty ? '0' : _value}.';
      } else {
        if (_value == '0') {
          _value = key;
          return;
        }
        if (_value.contains('.') && _value.split('.')[1].length >= 2) return;
        if (!_value.contains('.') && _value.length >= 6) return;
        _value += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final valid = _amount != null && _amount! > 0;
    return Dialog(
      backgroundColor: const Color(0xFFFDFDFD),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Saisissez votre montant',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: _gold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: _gold, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                  '${_value.isEmpty ? '0' : _value.replaceAll('.', ',')} €',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 46,
                    color: _grey,
                    fontWeight: FontWeight.bold,
                  ),
                )),
              ),
              const SizedBox(height: 28),
              GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: MediaQuery.sizeOf(context).width < 500 ? 80 : 110,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children:
                    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', 'C']
                        .map(
                          (key) => DonationButton(
                            label: key,
                            fontSize: 34,
                            grey: key == '⌫' || key == 'C',
                            baseColor: key == '⌫' || key == 'C'
                              ? (widget.customColor == _grey ? null : widget.customColor)
                              : (widget.amountColor == _gold ? null : widget.amountColor),
                            onTap: () => _key(key),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(child: SizedBox(height: 82, child: DonationButton(
                  label: 'Valider', fontSize: 20, subtle: true, baseColor: const Color(0xFF31B347),
                  onTap: valid ? () => Navigator.pop(context, _amount) : null,
                ))),
                const SizedBox(width: 16),
                Expanded(child: SizedBox(height: 82, child: DonationButton(
                  label: 'Annuler', fontSize: 20, subtle: true, baseColor: const Color(0xFFE53935),
                  onTap: () => Navigator.pop(context),
                ))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
