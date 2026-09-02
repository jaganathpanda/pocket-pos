import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'store_auth_controller.dart';

/// Login for platform weighbridge operators (email + password).
class OperatorLoginPage extends ConsumerStatefulWidget {
  const OperatorLoginPage({super.key});

  @override
  ConsumerState<OperatorLoginPage> createState() => _OperatorLoginPageState();
}

class _OperatorLoginPageState extends ConsumerState<OperatorLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref.read(storeAuthControllerProvider.notifier).operatorLogin(
          email: _email.text,
          password: _password.text,
        );
    if (!ok && mounted) {
      final err = ref.read(storeAuthControllerProvider).error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err ?? 'Login failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(storeAuthControllerProvider).busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Weighbridge Operator')),
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
                    const Icon(Icons.scale_rounded,
                        size: 48, color: Color(0xFF005D4D)),
                    const SizedBox(height: 8),
                    const Text('Operator Sign In',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
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
                          busy ? null : () => context.push('/operator-register'),
                      child: const Text('Register as operator'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => context.go('/store-login'),
                      child: const Text('Back to store login'),
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
