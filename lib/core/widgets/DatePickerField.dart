// ── lib/core/widgets/date_picker_field.dart ──

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DatePickerField extends StatelessWidget {
  const DatePickerField({
    super.key,
    required this.date,
    required this.onDatePicked,
    this.tooltip,
    this.label = 'Date',
    this.isRequired = false,
    this.showInfoIcon = true,
  });

  final DateTime date;
  final ValueChanged<DateTime> onDatePicked;
  final String? tooltip;
  final String label;
  final bool isRequired;
  final bool showInfoIcon;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      onDatePicked(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today, size: 18),
      title: Text(
        DateFormat('dd/MM/yyyy').format(date),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(isRequired ? '$label *' : label),
      onTap: () => _pickDate(context),
    );

    if (tooltip != null && showInfoIcon) {
      return Stack(
        alignment: Alignment.centerRight,
        children: [
          child,
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
              message: tooltip!,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      );
    }

    return child;
  }
}
