// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reviews_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$reviewsRepositoryHash() => r'7bfc10b7def2c521bde7fb4ab17b164b55193d39';

/// See also [reviewsRepository].
@ProviderFor(reviewsRepository)
final reviewsRepositoryProvider =
    AutoDisposeProvider<ReviewsRepository>.internal(
      reviewsRepository,
      name: r'reviewsRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$reviewsRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReviewsRepositoryRef = AutoDisposeProviderRef<ReviewsRepository>;
String _$lawyerReviewsHash() => r'b635de41fa46a3503c45e91a354079d594277f85';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [lawyerReviews].
@ProviderFor(lawyerReviews)
const lawyerReviewsProvider = LawyerReviewsFamily();

/// See also [lawyerReviews].
class LawyerReviewsFamily extends Family<AsyncValue<List<Review>>> {
  /// See also [lawyerReviews].
  const LawyerReviewsFamily();

  /// See also [lawyerReviews].
  LawyerReviewsProvider call(String lawyerId) {
    return LawyerReviewsProvider(lawyerId);
  }

  @override
  LawyerReviewsProvider getProviderOverride(
    covariant LawyerReviewsProvider provider,
  ) {
    return call(provider.lawyerId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'lawyerReviewsProvider';
}

/// See also [lawyerReviews].
class LawyerReviewsProvider extends AutoDisposeFutureProvider<List<Review>> {
  /// See also [lawyerReviews].
  LawyerReviewsProvider(String lawyerId)
    : this._internal(
        (ref) => lawyerReviews(ref as LawyerReviewsRef, lawyerId),
        from: lawyerReviewsProvider,
        name: r'lawyerReviewsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$lawyerReviewsHash,
        dependencies: LawyerReviewsFamily._dependencies,
        allTransitiveDependencies:
            LawyerReviewsFamily._allTransitiveDependencies,
        lawyerId: lawyerId,
      );

  LawyerReviewsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.lawyerId,
  }) : super.internal();

  final String lawyerId;

  @override
  Override overrideWith(
    FutureOr<List<Review>> Function(LawyerReviewsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LawyerReviewsProvider._internal(
        (ref) => create(ref as LawyerReviewsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        lawyerId: lawyerId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Review>> createElement() {
    return _LawyerReviewsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LawyerReviewsProvider && other.lawyerId == lawyerId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, lawyerId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LawyerReviewsRef on AutoDisposeFutureProviderRef<List<Review>> {
  /// The parameter `lawyerId` of this provider.
  String get lawyerId;
}

class _LawyerReviewsProviderElement
    extends AutoDisposeFutureProviderElement<List<Review>>
    with LawyerReviewsRef {
  _LawyerReviewsProviderElement(super.provider);

  @override
  String get lawyerId => (origin as LawyerReviewsProvider).lawyerId;
}

String _$reviewControllerHash() => r'1363ed4eef90ed627d14f0703703c53290730015';

/// See also [ReviewController].
@ProviderFor(ReviewController)
final reviewControllerProvider =
    AutoDisposeAsyncNotifierProvider<ReviewController, void>.internal(
      ReviewController.new,
      name: r'reviewControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$reviewControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ReviewController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
