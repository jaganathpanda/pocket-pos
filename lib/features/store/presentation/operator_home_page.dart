import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'store_auth_controller.dart';

/// Shown to an approved operator before they pick a mill. They type a mill's
/// Store ID to enter it; on success the app scopes to that mill and routes to
/// the weighbridge dashboard.
class OperatorHomePage extends ConsumerStatefulWidget {
  const OperatorHomePage({super.key});

  @override
  ConsumerState<OperatorHomePage> createState() => _OperatorHomePageState();
}

class _OperatorHomePageState extends ConsumerState<OperatorHomePage> {
  final _storeId = TextEditingController();

  @override
  void dispose() {
    _storeId.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final id = _storeId.text.trim();
    if (id.isEmpty) return;
    final ok = await ref.read(storeAuthControllerProvider.notifier).enterMill(id);
    if (!ok && mounted) {
      final err = ref.read(storeAuthControllerProvider).error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err ?? 'Could not enter mill')));
    }
    // On success the router redirect moves to the weighbridge dashboard.
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeAuthControllerProvider);
    final name = state.operator?.name ?? 'Operator';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Mill'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(storeAuthControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.factory_rounded,
                        size: 48, color: Color(0xFF005D4D)),
                    const SizedBox(height: 8),
                    Text('Welcome, $name',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('Enter the mill\'s Store ID to start',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _storeId,
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (_) => state.busy ? null : _enter(),
                      decoration: const InputDecoration(
                        labelText: 'Store ID',
                        hintText: 'STR-XXXXXX',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: state.busy ? null : _enter,
                        child: state.busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Enter Mill'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
