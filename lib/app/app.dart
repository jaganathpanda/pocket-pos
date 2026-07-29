import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/providers.dart';
import '../features/store/domain/store_models.dart';
import '../features/store/presentation/store_auth_controller.dart';
import 'router.dart';

class PocketPosApp extends ConsumerWidget {
  const PocketPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bridge the cloud store session into the app's local session so existing
    // POS screens keep working once a store owner is signed in.
    ref.listen<StoreAuthState>(storeAuthControllerProvider, (prev, next) {
      if (next.stage == StoreAuthStage.active) {
        final s = next.session;
        ref.read(authControllerProvider.notifier).enterFromStore(
              username: s?.username ?? 'owner',
              role: s?.role ?? 'owner',
              posCounterId: s?.posCounterId,
            );
      } else if (next.stage == StoreAuthStage.loggedOut) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Pocket POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005D4D)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
