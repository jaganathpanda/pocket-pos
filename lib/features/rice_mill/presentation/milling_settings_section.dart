import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MillingSettingsSection extends StatelessWidget {
  const MillingSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.factory_rounded),
        title: const Text('Milling Configuration'),
        subtitle: const Text('Rates, deductions, GST, TDS, and yield warnings'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/milling-config'),
      ),
    );
  }
}
