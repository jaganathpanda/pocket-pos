import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/di/providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isResetting = false;

  Future<void> _resetDemoData() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset demo data?'),
        content: const Text('This will clear current web data and re-seed mock users, products, and inventory.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset != true || !mounted) return;

    setState(() => _isResetting = true);
    try {
      await ref.read(appDatabaseProvider).resetWebDemoData();
      ref.invalidate(categoriesProvider);
      ref.invalidate(productsProvider);
      ref.invalidate(inventoryProvider);
      ref.invalidate(activeCartsProvider);
      ref.invalidate(dashboardMetricsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo data reset complete.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Demo Data',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    kIsWeb
                        ? 'Reset and re-seed mock web data for demos and testing.'
                        : 'Demo data reset is only available on web builds.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: !kIsWeb || _isResetting ? null : _resetDemoData,
                    icon: _isResetting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restart_alt_rounded),
                    label: Text(_isResetting ? 'Resetting...' : 'Reset Demo Data'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
