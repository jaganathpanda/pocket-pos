import 'package:flutter/material.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({
    super.key,
    required this.title,
    required this.helpItems,
  });

  final String title;
  final List<HelpItem> helpItems;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.help_outline, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 600 ? 500 : double.infinity,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in helpItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.description,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class HelpItem {
  const HelpItem({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;
}

// ── Paddy Procurement Help Dialog ──

class PaddyProcurementHelpDialog extends StatelessWidget {
  const PaddyProcurementHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const HelpDialog(
      title: 'Paddy Procurement Field Guide',
      helpItems: [
        HelpItem(
          label: 'Gr.Wt',
          description: 'Gross weight: Vehicle + Paddy load (in Kg)',
        ),
        HelpItem(
          label: 'Tr.Wt',
          description: 'Tare weight: Empty vehicle after unloading (in Kg)',
        ),
        HelpItem(
          label: 'J.Pkt',
          description: 'Number of Jute/Gunny bags',
        ),
        HelpItem(
          label: 'P.Pkt',
          description: 'Number of Plastic bags',
        ),
        HelpItem(
          label: 'MKT/FT',
          description:
              'MKT: Market/Mandi procurement\nFT: Direct Farmer procurement',
        ),
        HelpItem(
          label: 'Quality Cuts',
          description: 'Deductions for poor quality grain (Dust, Pol, Other)',
        ),
        HelpItem(
          label: 'Gny Wt(Less)',
          description: 'Deduct gunny bag weight from net weight',
        ),
        HelpItem(
          label: 'Bag Rtn',
          description: 'Will empty gunny bags be returned?',
        ),
      ],
    );
  }
}
