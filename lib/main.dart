import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Offline-first: cache Firestore data locally and sync when back online.
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    // Some enterprise/proxy networks break WebChannel streaming and can
    // stall reads after sign-in on web. Auto-detect long-polling to keep
    // authentication and session reads reliable.
    webExperimentalAutoDetectLongPolling: kIsWeb ? true : null,
  );
  runApp(const ProviderScope(child: PocketPosApp()));
}
