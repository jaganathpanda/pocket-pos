import 'package:flutter/material.dart';

import 'parent_modal_bridge.dart';

/// Dismisses the marketing site's registration modal from inside the iframe.
///
/// Renders nothing unless the app is actually embedded, so the same widget can
/// sit on the registration screen without adding a dead button to the
/// standalone page.
class CloseModalButton extends StatelessWidget {
  const CloseModalButton({super.key, this.label = 'Close'});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (!isEmbeddedInParent) return const SizedBox.shrink();

    return ElevatedButton.icon(
      onPressed: closeParentModal,
      icon: const Icon(Icons.close),
      label: Text(label),
    );
  }
}
