import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_pos/features/table_booking/domain/table_reservation.dart';

void main() {
  final start = DateTime(2026, 10, 1, 18);
  final reservation = TableReservation(
    id: 1,
    guestName: 'Asha',
    mobile: '',
    tableName: 'Table 1',
    guestCount: 2,
    startAt: start,
    endAt: start.add(const Duration(minutes: 90)),
    status: 'booked',
  );

  test('overlaps reservations for the same table and time', () {
    expect(
      reservation.overlaps(
        table: ' table 1 ',
        start: start.add(const Duration(minutes: 30)),
        end: start.add(const Duration(minutes: 120)),
      ),
      isTrue,
    );
  });

  test('allows an adjacent reservation when the earlier one ends', () {
    expect(
      reservation.overlaps(
        table: 'Table 1',
        start: reservation.endAt,
        end: reservation.endAt.add(const Duration(minutes: 60)),
      ),
      isFalse,
    );
  });

  test('does not block another table or a cancelled reservation', () {
    expect(
      reservation.overlaps(
        table: 'Table 2',
        start: start,
        end: reservation.endAt,
      ),
      isFalse,
    );
    expect(
      TableReservation(
        id: reservation.id,
        guestName: reservation.guestName,
        mobile: reservation.mobile,
        tableName: reservation.tableName,
        guestCount: reservation.guestCount,
        startAt: reservation.startAt,
        endAt: reservation.endAt,
        status: 'cancelled',
      ).overlaps(
        table: 'Table 1',
        start: start,
        end: reservation.endAt,
      ),
      isFalse,
    );
  });
}
