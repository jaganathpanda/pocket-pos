import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_pos/features/table_booking/data/firestore_table_reservation_repository.dart';
import 'package:pocket_pos/features/table_booking/domain/table_reservation.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreTableReservationRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreTableReservationRepository(firestore, 'hotel-1');
  });

  test('adds configured tables and rejects duplicate names', () async {
    await repository.addTable('  Table   1 ');
    expect((await repository.watchTables().first).map((table) => table.name),
        ['Table 1']);

    await expectLater(
      repository.addTable('table 1'),
      throwsA(isA<StateError>()),
    );
  });

  test('booking requires configured table and prevents overlapping times',
      () async {
    final start = DateTime(2026, 10, 1, 18);
    final firstBooking = TableReservationDraft(
      guestName: 'Asha',
      mobile: '',
      tableName: 'Table 1',
      guestCount: 2,
      startAt: start,
      durationMinutes: 90,
    );

    await expectLater(
        repository.create(firstBooking), throwsA(isA<StateError>()));

    await repository.addTable('Table 1');
    await repository.create(firstBooking);
    await expectLater(
      repository.create(
        TableReservationDraft(
          guestName: 'Ravi',
          mobile: '',
          tableName: 'table 1',
          guestCount: 3,
          startAt: start.add(const Duration(minutes: 30)),
          durationMinutes: 60,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('cannot remove a table with an active booking', () async {
    await repository.addTable('Table 1');
    await repository.create(
      TableReservationDraft(
        guestName: 'Asha',
        mobile: '',
        tableName: 'Table 1',
        guestCount: 2,
        startAt: DateTime(2026, 10, 1, 18),
        durationMinutes: 90,
      ),
    );

    await expectLater(
      repository.removeTable('Table 1'),
      throwsA(isA<StateError>()),
    );
  });
}
