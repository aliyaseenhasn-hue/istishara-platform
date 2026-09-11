// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$bookingsRepositoryHash() =>
    r'0f2e9089ae436541cfb851a66986c47c4d0e886e';

/// See also [bookingsRepository].
@ProviderFor(bookingsRepository)
final bookingsRepositoryProvider =
    AutoDisposeProvider<BookingsRepository>.internal(
  bookingsRepository,
  name: r'bookingsRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$bookingsRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BookingsRepositoryRef = AutoDisposeProviderRef<BookingsRepository>;
String _$userBookingsHash() => r'1f732a5d5875cf60857994ea8a922cd288420310';

/// See also [userBookings].
@ProviderFor(userBookings)
final userBookingsProvider = FutureProvider<List<Booking>>.internal(
  userBookings,
  name: r'userBookingsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userBookingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserBookingsRef = FutureProviderRef<List<Booking>>;
String _$lawyerBookingsHash() => r'6a31a2664c17adc0c4f2103df5b6f8426610c4f6';

/// See also [lawyerBookings].
@ProviderFor(lawyerBookings)
final lawyerBookingsProvider =
    FutureProvider<List<Booking>>.internal(
  lawyerBookings,
  name: r'lawyerBookingsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$lawyerBookingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LawyerBookingsRef = FutureProviderRef<List<Booking>>;
String _$bookingsControllerHash() =>
    r'3f7735accd14f12023e0bfb03d0051dbd49acea8';

/// See also [BookingsController].
@ProviderFor(BookingsController)
final bookingsControllerProvider =
    AutoDisposeAsyncNotifierProvider<BookingsController, void>.internal(
  BookingsController.new,
  name: r'bookingsControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$bookingsControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BookingsController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
