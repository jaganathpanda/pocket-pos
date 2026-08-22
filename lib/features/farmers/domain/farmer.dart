import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Farmer extends Equatable {
  final int id;
  final String name;
  final String type; // 'farmer' or 'mandi'
  final String? mobile;
  final String? gstNumber;
  final String? email;
  final String? address;
  final String? contactPerson;
  final double outstandingBalance;
  final bool isActive;
  final DateTime createdAt;

  // Farmer-specific fields
  final String? kisanCardNumber;
  final String? aadhaarNumber;
  final String? village;
  final String? district;
  final String? mandiLicenseNumber; // For mandi agents

  const Farmer({
    required this.id,
    required this.name,
    required this.type,
    this.mobile,
    this.gstNumber,
    this.email,
    this.address,
    this.contactPerson,
    this.outstandingBalance = 0,
    this.isActive = true,
    required this.createdAt,
    this.kisanCardNumber,
    this.aadhaarNumber,
    this.village,
    this.district,
    this.mandiLicenseNumber,
  });

  Farmer copyWith({
    int? id,
    String? name,
    String? type,
    String? mobile,
    String? gstNumber,
    String? email,
    String? address,
    String? contactPerson,
    double? outstandingBalance,
    bool? isActive,
    DateTime? createdAt,
    String? kisanCardNumber,
    String? aadhaarNumber,
    String? village,
    String? district,
    String? mandiLicenseNumber,
  }) {
    return Farmer(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      mobile: mobile ?? this.mobile,
      gstNumber: gstNumber ?? this.gstNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      kisanCardNumber: kisanCardNumber ?? this.kisanCardNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      village: village ?? this.village,
      district: district ?? this.district,
      mandiLicenseNumber: mandiLicenseNumber ?? this.mandiLicenseNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'mobile': mobile,
      'gstNumber': gstNumber,
      'email': email,
      'address': address,
      'contactPerson': contactPerson,
      'outstandingBalance': outstandingBalance,
      'isActive': isActive,
      'createdAt': createdAt,
      'kisanCardNumber': kisanCardNumber,
      'aadhaarNumber': aadhaarNumber,
      'village': village,
      'district': district,
      'mandiLicenseNumber': mandiLicenseNumber,
    };
  }

  factory Farmer.fromMap(Map<String, dynamic> map) {
    return Farmer(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'farmer',
      mobile: map['mobile'] as String?,
      gstNumber: map['gstNumber'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      contactPerson: map['contactPerson'] as String?,
      outstandingBalance: (map['outstandingBalance'] as num?)?.toDouble() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: map['createdAt'] as DateTime? ?? DateTime.now(),
      kisanCardNumber: map['kisanCardNumber'] as String?,
      aadhaarNumber: map['aadhaarNumber'] as String?,
      village: map['village'] as String?,
      district: map['district'] as String?,
      mandiLicenseNumber: map['mandiLicenseNumber'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, type];

  String get displayName => name;
  String get displayType => type == 'mandi' ? 'Mandi Agent' : 'Farmer';
  IconData get icon =>
      type == 'mandi' ? Icons.storefront_rounded : Icons.person_rounded;
}
