import 'package:flutter/material.dart';

/// A form field with built-in tooltip info icon.
///
/// Example:
/// ```dart
/// TooltipFormField(
///   labelText: 'Gr.Wt',
///   tooltip: Tooltips.paddyProcurement.grossWeight,
///   controller: _grossWtCtrl,
///   keyboardType: TextInputType.number,
///   isRequired: true,
/// )
/// ```
class TooltipFormField extends StatelessWidget {
  const TooltipFormField({
    super.key,
    required this.labelText,
    required this.tooltip,
    this.controller,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.initialValue,
    this.enabled = true,
    this.isRequired = false,
    this.suffixText,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.onTap,
    this.textCapitalization = TextCapitalization.none,
  });

  final String labelText;
  final String tooltip;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final String? initialValue;
  final bool enabled;
  final bool isRequired;
  final String? suffixText;
  final bool obscureText;
  final int maxLines;
  final int? minLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          keyboardType: keyboardType,
          enabled: enabled,
          obscureText: obscureText,
          maxLines: maxLines,
          minLines: minLines,
          readOnly: readOnly,
          onTap: onTap,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            labelText: isRequired ? '$labelText *' : labelText,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixText: suffixText,
            suffixStyle: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          validator: validator,
          onChanged: onChanged,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8, top: 4),
          child: Tooltip(
            message: tooltip,
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ),
        ),
      ],
    );
  }
}
