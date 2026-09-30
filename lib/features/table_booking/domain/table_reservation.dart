class TableReservation {
  const TableReservation({
    required this.id,
    required this.guestName,
    required this.mobile,
    required this.tableName,
    required this.guestCount,
    required this.startAt,
    required this.endAt,
    required this.status,
  });

  final int id;
  final String guestName;
  final String mobile;
  final String tableName;
  final int guestCount;
  final DateTime startAt;
  final DateTime endAt;
  final String status;

  bool get occupiesTable => status == 'booked' || status == 'seated';

  bool overlaps({
    required String table,
    required DateTime start,
    required DateTime end,
  }) {
    return occupiesTable &&
        tableName.trim().toLowerCase() == table.trim().toLowerCase() &&
        startAt.isBefore(end) &&
        start.isBefore(endAt);
  }
}

class TableReservationDraft {
  const TableReservationDraft({
    required this.guestName,
    required this.mobile,
    required this.tableName,
    required this.guestCount,
    required this.startAt,
    required this.durationMinutes,
  });

  final String guestName;
  final String mobile;
  final String tableName;
  final int guestCount;
  final DateTime startAt;
  final int durationMinutes;

  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));
}
