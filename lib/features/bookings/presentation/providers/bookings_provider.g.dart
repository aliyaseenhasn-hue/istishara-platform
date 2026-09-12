// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$bookingsRepositoryHash() =>
    r'10c3b652cb4c5216cacf246c4c587e0a52a1cf41';

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
String _$userBookingsHash() => r'f1a1cfb963f5f20177de6bcb69d4433233811b64';

/// See also [userBookings].
@ProviderFor(userBookings)
final userBookingsProvider = FutureProvider<List<Booking>>.internal(
  userBookings,
  name: r'userBookingsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userBookingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserBookingsRef = FutureProviderRef<List<Booking>>;
String _$lawyerBookingsHash() => r'd7cca4c2691349e2d4d1f128e9a8ab3b5fcb4d2f';

/// See also [lawyerBookings].
@ProviderFor(lawyerBookings)
final lawyerBookingsProvider = FutureProvider<List<Booking>>.internal(
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
    r'bd8e94a570ff310f57df0a8bc97ec84d56ffa3d0';

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
