import 'app/app.dart';
import 'bootstrap.dart';
import 'features/rice_mill/rice_mill_router.dart';

Future<void> main() => runPocketPosApp(
      PocketPosApp(routerProvider: riceMillRouterProvider),
    );
