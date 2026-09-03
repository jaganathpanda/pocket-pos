import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import 'store_auth_controller.dart';

class StoreLoginPage extends ConsumerStatefulWidget {
  const StoreLoginPage({super.key});

  @override
  ConsumerState<StoreLoginPage> createState() => _StoreLoginPageState();
}

class _StoreLoginPageState extends ConsumerState<StoreLoginPage> {
  final _storeId = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _storeId.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref.read(storeAuthControllerProvider.notifier).login(
          storeId: _storeId.text,
          username: _username.text,
          password: _password.text,
        );
    if (!ok && mounted) {
      final err = ref.read(storeAuthControllerProvider).error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err ?? 'Login failed')));
    }
    // On success the router redirect moves to the app / pending screen.
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(storeAuthControllerProvider).busy;
    final allowPublicStorefront =
        ref.watch(platformAnonymousShoppingEnabledProvider);

    return Scaffold(
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
                    const Icon(Icons.storefront_rounded,
                        size: 48, color: Color(0xFF005D4D)),
                    const SizedBox(height: 8),
                    const Text('Pocket POS',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text('Sign in to your store',
                        style: TextStyle(color: Colors.grey)),
                    if (!allowPublicStorefront) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.amber.shade800,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Public shopping is currently disabled by platform.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextField(
                      controller: _storeId,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Store ID',
                        hintText: 'STR-XXXXXX',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _username,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      onSubmitted: (_) => busy ? null : _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed:
                          busy ? null : () => context.push('/store-register'),
                      child: const Text('Register a new store'),
                    ),
                    TextButton(
                      onPressed:
                          busy ? null : () => context.push('/admin-login'),
                      child: const Text('Platform admin login'),
                    ),
                    TextButton(
                      onPressed:
                          busy ? null : () => context.push('/operator-login'),
                      child: const Text('Weighbridge operator login'),
                    ),
                    if (allowPublicStorefront)
                      TextButton(
                        onPressed:
                            busy ? null : () => context.push('/storefront'),
                        child: const Text('Continue as customer'),
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
