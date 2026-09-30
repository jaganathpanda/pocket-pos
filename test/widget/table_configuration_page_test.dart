import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_pos/core/di/providers.dart';
import 'package:pocket_pos/features/table_booking/domain/restaurant_table.dart';
import 'package:pocket_pos/features/table_booking/domain/table_reservation.dart';
import 'package:pocket_pos/features/table_booking/domain/table_reservation_repository.dart';
import 'package:pocket_pos/features/table_booking/presentation/table_configuration_page.dart';

void main() {
  testWidgets('submitting a table disposes the dialog without framework errors',
      (tester) async {
    final repository = _FakeTableReservationRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tableReservationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: TableConfigurationPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add table'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Table 1');
    await tester.tap(find.text('Add table').last);
    await tester.pumpAndSettle();

    expect(repository.addedTables, ['Table 1']);
    expect(tester.takeException(), isNull);
  });
}

class _FakeTableReservationRepository implements TableReservationRepository {
  final addedTables = <String>[];

  @override
  Stream<List<RestaurantTable>> watchTables() =>
      Stream.value(const <RestaurantTable>[]);

  @override
  Stream<List<TableReservation>> watchAll() =>
      Stream.value(const <TableReservation>[]);

  @override
  Future<void> addTable(String name) async {
    addedTables.add(name);
  }

  @override
  Future<void> removeTable(String name) async {}

  @override
  Future<void> create(TableReservationDraft draft) async {}

  @override
  Future<void> updateStatus(int id, String status) async {}
}
