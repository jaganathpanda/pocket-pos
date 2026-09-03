import 'package:flutter/material.dart';

/// A simple tooltip icon for use anywhere.
///
/// Example:
/// ```dart
/// TooltipIcon(
///   tooltip: Tooltips.general.help,
///   icon: Icons.help_outline,
///   onTap: () => showHelpDialog(),
/// )
/// ```
class TooltipIcon extends StatelessWidget {
  const TooltipIcon({
    super.key,
    required this.tooltip,
    this.icon = Icons.info_outline,
    this.size = 18,
    this.color,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final double size;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final widget = Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size: size,
        color: color ?? Colors.grey.shade400,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: widget,
        ),
      );
    }

    return widget;
  }
}
