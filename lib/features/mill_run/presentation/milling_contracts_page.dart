import 'package:flutter/material.dart';

/// Placeholder page for Milling Rate Contracts — party-specific rate agreements
/// that drive auto-calculation in milling charge invoices.
/// Accessible from Settings → Milling Charge Defaults → Manage Party Rate Contracts.
class MillingContractsPage extends StatelessWidget {
  const MillingContractsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Milling Rate Contracts')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.handshake_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Party Rate Contracts',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Define per-party milling charge rates, GST %, TDS, and validity dates.\n'
              'These contracts override global defaults at invoice time.\nComing in Phase 6.4.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
