import 'package:drift/drift.dart';
import 'package:drift/web.dart';

Future<QueryExecutor> openConnection() async {
  return WebDatabase('pocket_pos_web');
}
