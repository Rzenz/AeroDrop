import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/card_validator.dart';
import '../../../core/widgets/neu_button.dart';

class SimulatedCardDialog extends StatefulWidget {
  final double amount;
  final ValueChanged<String> onCardValidated;

  const SimulatedCardDialog({
    super.key,
    required this.amount,
    required this.onCardValidated,
  });

  static Future<String?> show(BuildContext context, {required double amount}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SimulatedCardDialog(
        amount: amount,
        onCardValidated: (maskedCard) {
          Navigator.of(ctx).pop(maskedCard);
        },
      ),
    );
  }

  @override
  State<SimulatedCardDialog> createState() => _SimulatedCardDialogState();
}

class _SimulatedCardDialogState extends State<SimulatedCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _holderController = TextEditingController();

  String _detectedBrand = 'Card';

  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(() {
      final brand = CardValidator.detectBrand(_cardNumberController.text);
      if (brand != _detectedBrand) {
        setState(() => _detectedBrand = brand);
      }
    });
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;

    final rawNumber = _cardNumberController.text.replaceAll(RegExp(r'\s+|-'), '');
    final last4 = rawNumber.length >= 4 ? rawNumber.substring(rawNumber.length - 4) : '0000';
    final brand = _detectedBrand;

    // Discard sensitive controllers immediately
    _cardNumberController.clear();
    _cvvController.clear();
    _expiryController.clear();

    widget.onCardValidated('$brand •••• $last4');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.credit_card_rounded,
                      color: Color(0xFFA855F7),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Credit / Debit Card',
                          style: AppTextStyles.title(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Simulated payment • ₱${widget.amount.toStringAsFixed(2)}',
                          style: AppTextStyles.caption(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Cardholder Name
              TextFormField(
                controller: _holderController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDecoration(
                  label: 'Cardholder Name',
                  hint: 'e.g. Juan Dela Cruz',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter cardholder name';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Card Number
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(19),
                  _CardNumberInputFormatter(),
                ],
                style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1.2),
                decoration: _inputDecoration(
                  label: 'Card Number',
                  hint: '4532 •••• •••• 8943',
                  icon: Icons.credit_card_outlined,
                  suffixText: _detectedBrand != 'Card' ? _detectedBrand : null,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter card number';
                  if (!CardValidator.isValidLuhn(v)) return 'Invalid card number checksum';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Expiry + CVV row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _ExpiryInputFormatter(),
                      ],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration(
                        label: 'Expires (MM/YY)',
                        hint: 'MM/YY',
                        icon: Icons.calendar_today_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter MM/YY';
                        if (!CardValidator.isValidExpiry(v)) return 'Invalid or expired';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration(
                        label: 'CVV / CVC',
                        hint: '123',
                        icon: Icons.lock_outline_rounded,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter CVV';
                        if (!CardValidator.isValidCvv(v)) return '3-4 digits';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Simulated sandbox payment. Sensitive card data is never saved.',
                        style: AppTextStyles.caption(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: NeuButton(
                      text: 'Cancel',
                      variant: NeuButtonVariant.neutral,
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeuButton(
                      text: 'Pay ₱${widget.amount.toStringAsFixed(2)}',
                      variant: NeuButtonVariant.primary,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
      hintStyle: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.5)),
      prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
      suffixText: suffixText,
      suffixStyle: const TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.bold, fontSize: 12),
      filled: true,
      fillColor: AppColors.cardDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA855F7), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
