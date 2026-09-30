import 'restaurant_table.dart';
import 'table_reservation.dart';

abstract class TableReservationRepository {
  Stream<List<RestaurantTable>> watchTables();
  Stream<List<TableReservation>> watchAll();
  Future<void> addTable(String name);
  Future<void> removeTable(String name);
  Future<void> create(TableReservationDraft draft);
  Future<void> updateStatus(int id, String status);
}
