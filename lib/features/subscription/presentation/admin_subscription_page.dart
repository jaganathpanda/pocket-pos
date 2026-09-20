import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_subscription_panel.dart';

class AdminSubscriptionPage extends StatelessWidget {
  const AdminSubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Subscriptions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: const SafeArea(child: AdminSubscriptionPanel()),
    );
  }
}
