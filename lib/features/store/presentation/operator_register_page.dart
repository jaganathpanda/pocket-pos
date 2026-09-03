import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'store_auth_controller.dart';

/// Self-registration for platform weighbridge operators. Creates a pending
/// account that a platform admin must approve before it can be used.
class OperatorRegisterPage extends ConsumerStatefulWidget {
  const OperatorRegisterPage({super.key});

  @override
  ConsumerState<OperatorRegisterPage> createState() =>
      _OperatorRegisterPageState();
}

class _OperatorRegisterPageState extends ConsumerState<OperatorRegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name, email and a 6+ char password are required.')));
      return;
    }
    final ok = await ref.read(storeAuthControllerProvider.notifier).registerOperator(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          mobile: _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      // The router redirect moves to the pending screen on success.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Registered! Awaiting platform approval.')));
    } else {
      final err = ref.read(storeAuthControllerProvider).error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err ?? 'Registration failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(storeAuthControllerProvider).busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Register as Operator')),
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
                    const Text('Weighbridge Operator',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const Text('Platform account for rice mills',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                      controller: _mobile,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password (6+ chars)',
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
                            : const Text('Register'),
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => context.pop(),
                      child: const Text('Back'),
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
