// custom_stepper.dart
//
// A clean, Shadcn-style custom vertical stepper widget. It displays the current checkout phase
// (Select Amount -> Processing -> Confirmed) with minimalist typography and clear circular nodes.
import 'package:flutter/material.dart';
import '../../../core/constants.dart';

class CustomStepper extends StatelessWidget {
  final int currentStep; // 1, 2, or 3
  final Color color;

  const CustomStepper({
    super.key,
    required this.currentStep,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = (MediaQuery.sizeOf(context).width / 1080 * 24).clamp(12.0, 24.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepItem(
          fontSize: fontSize,
          stepNumber: 1,
          label: 'Choisissez votre montant',
          isActive: currentStep == 1,
        ),
        _buildStepItem(
          fontSize: fontSize,
          stepNumber: 2,
          label: 'Procédez au paiement',
          isActive: currentStep == 2,
        ),
        _buildStepItem(
          fontSize: fontSize,
          stepNumber: 3,
          label: 'Confirmation de paiement',
          isActive: currentStep == 3,
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required double fontSize,
    required int stepNumber,
    required String label,
    required bool isActive,
  }) {
    final Color circleBgColor = isActive ? color : Colors.white;
    final Color numberColor = isActive ? Colors.white : color;
    final Color labelColor = isActive ? color : AppConstants.mutedForeground;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: circleBgColor,
              border: Border.all(color: color, width: 2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
                    '$stepNumber',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: numberColor,
                    ),
                  ),
          ),
          const SizedBox(height: 8.0),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'ReemKufi',
              fontSize: fontSize,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }

}
