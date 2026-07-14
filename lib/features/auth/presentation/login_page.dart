import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _username = TextEditingController(text: 'owner');
  final _pin = TextEditingController(text: '1234');

  @override
  void dispose() {
    _username.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pocket POS Login', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username')),
                  const SizedBox(height: 12),
                  TextField(controller: _pin, decoration: const InputDecoration(labelText: 'PIN'), obscureText: true),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await ref.read(authControllerProvider.notifier).login(_username.text.trim(), _pin.text.trim());
                            if (!context.mounted) return;
                            if (ok) {
                              final user = ref.read(currentUserProvider);
                              final where = user?.posCounterName ?? 'All counters';
                              context.go('/dashboard');
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Signed in as ${user?.username ?? ''}  ·  $where'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } else {
                              final authState = ref.read(authControllerProvider);
                              final message = authState.hasError
                                  ? 'Login failed: ${authState.error}'
                                  : 'Invalid credentials';
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                            }
                          },
                    child: auth.isLoading ? const CircularProgressIndicator() : const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
