enum StoreStatus { pending, approved, suspended, unknown }

StoreStatus storeStatusFromString(String? value) {
  switch (value) {
    case 'approved':
      return StoreStatus.approved;
    case 'suspended':
      return StoreStatus.suspended;
    case 'pending':
      return StoreStatus.pending;
    default:
      return StoreStatus.unknown;
  }
}

/// The signed-in store user (tenant context for the whole app).
class StoreSession {
  const StoreSession({
    required this.storeId,
    required this.storeName,
    required this.uid,
    required this.username,
    required this.role,
    required this.status,
  });

  final String storeId;
  final String storeName;
  final String uid;
  final String username;
  final String role;
  final StoreStatus status;

  bool get isApproved => status == StoreStatus.approved;
}

/// A store awaiting (or granted) platform approval — used by the admin screen.
class StoreRecord {
  const StoreRecord({
    required this.storeId,
    required this.name,
    required this.ownerName,
    required this.status,
    this.mobile,
    this.email,
  });

  final String storeId;
  final String name;
  final String ownerName;
  final StoreStatus status;
  final String? mobile;
  final String? email;
}

/// Where the app boots to, based on Firebase auth + store status.
enum StoreAuthStage { unknown, loggedOut, pending, active, admin }

class StoreAuthState {
  const StoreAuthState({
    required this.stage,
    this.session,
    this.busy = false,
    this.error,
  });

  final StoreAuthStage stage;
  final StoreSession? session;
  final bool busy;
  final String? error;

  StoreAuthState copyWith({
    StoreAuthStage? stage,
    StoreSession? session,
    bool? busy,
    String? error,
  }) {
    return StoreAuthState(
      stage: stage ?? this.stage,
      session: session ?? this.session,
      busy: busy ?? this.busy,
      error: error,
    );
  }
}
