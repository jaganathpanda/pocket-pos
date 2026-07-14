import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Captures input from hardware "keyboard wedge" barcode scanners (USB or
/// Bluetooth HID). These devices type the barcode as very fast keystrokes
/// followed by Enter, so we buffer characters that arrive in quick succession
/// and emit the code when Enter is received.
///
/// Human typing is naturally ignored because keystrokes arrive slower than
/// [maxKeyGap]; the buffer resets whenever the gap is exceeded.
class HidScannerListener extends StatefulWidget {
  const HidScannerListener({
    super.key,
    required this.child,
    required this.onScan,
    this.enabled = true,
    this.minLength = 3,
    this.maxKeyGap = const Duration(milliseconds: 150),
  });

  final Widget child;
  final ValueChanged<String> onScan;
  final bool enabled;

  /// Minimum length of a buffered sequence to be treated as a scan.
  final int minLength;

  /// Maximum time allowed between keystrokes to still count as one scan.
  final Duration maxKeyGap;

  @override
  State<HidScannerListener> createState() => _HidScannerListenerState();
}

class _HidScannerListenerState extends State<HidScannerListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKey;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (!widget.enabled) return false;
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    // Too slow to be a scanner burst → treat as fresh input (human typing).
    if (_lastKey != null && now.difference(_lastKey!) > widget.maxKeyGap) {
      _buffer.clear();
    }
    _lastKey = now;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString().trim();
      _buffer.clear();
      if (code.length >= widget.minLength) {
        widget.onScan(code);
        return true; // consume Enter so it doesn't trigger other shortcuts
      }
      return false;
    }

    final char = event.character;
    if (char != null && char.length == 1 && char.codeUnitAt(0) >= 0x20) {
      _buffer.write(char);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
