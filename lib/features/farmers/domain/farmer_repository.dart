import 'farmer.dart';

abstract class FarmerRepository {
  /// Live stream of all farmers (active only)
  Stream<List<Farmer>> watchAll({String? type});

  /// Search farmers by name, mobile, or ID
  Future<List<Farmer>> search(String query, {String? type});

  /// Get a single farmer by ID
  Future<Farmer?> getById(int id);

  /// Add a new farmer
  Future<int> add({
    required String name,
    required String type, // 'farmer' or 'mandi'
    String? mobile,
    String? gstNumber,
    String? email,
    String? address,
    String? contactPerson,
    String? kisanCardNumber,
    String? aadhaarNumber,
    String? village,
    String? district,
    String? mandiLicenseNumber,
  });

  /// Update an existing farmer
  Future<void> update({
    required int id,
    required String name,
    required String type,
    String? mobile,
    String? gstNumber,
    String? email,
    String? address,
    String? contactPerson,
    String? kisanCardNumber,
    String? aadhaarNumber,
    String? village,
    String? district,
    String? mandiLicenseNumber,
  });

  /// Soft delete (set isActive = false)
  Future<void> delete(int id);
}
