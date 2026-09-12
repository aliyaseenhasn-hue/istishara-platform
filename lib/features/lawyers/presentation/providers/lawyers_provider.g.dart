// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lawyers_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$lawyersRepositoryHash() => r'38457caea744ba9819d03e55c9b2b9d2e0bda98a';

/// See also [lawyersRepository].
@ProviderFor(lawyersRepository)
final lawyersRepositoryProvider =
    AutoDisposeProvider<LawyersRepository>.internal(
      lawyersRepository,
      name: r'lawyersRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$lawyersRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LawyersRepositoryRef = AutoDisposeProviderRef<LawyersRepository>;
String _$lawyersListHash() => r'b27d48112b5d2150c7a0d263c36cc90b6ee51381';

/// See also [lawyersList].
@ProviderFor(lawyersList)
final lawyersListProvider = FutureProvider<List<LawyerProfile>>.internal(
  lawyersList,
  name: r'lawyersListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$lawyersListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LawyersListRef = FutureProviderRef<List<LawyerProfile>>;
String _$lawyerProfileHash() => r'387c0512bfb7a55d4e484fe3c81209fde042a616';

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

/// See also [lawyerProfile].
@ProviderFor(lawyerProfile)
const lawyerProfileProvider = LawyerProfileFamily();

/// See also [lawyerProfile].
class LawyerProfileFamily extends Family<AsyncValue<LawyerProfile?>> {
  /// See also [lawyerProfile].
  const LawyerProfileFamily();

  /// See also [lawyerProfile].
  LawyerProfileProvider call(String profileId) {
    return LawyerProfileProvider(profileId);
  }

  @override
  LawyerProfileProvider getProviderOverride(
    covariant LawyerProfileProvider provider,
  ) {
    return call(provider.profileId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'lawyerProfileProvider';
}

/// See also [lawyerProfile].
class LawyerProfileProvider extends FutureProvider<LawyerProfile?> {
  /// See also [lawyerProfile].
  LawyerProfileProvider(String profileId)
    : this._internal(
        (ref) => lawyerProfile(ref as LawyerProfileRef, profileId),
        from: lawyerProfileProvider,
        name: r'lawyerProfileProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$lawyerProfileHash,
        dependencies: LawyerProfileFamily._dependencies,
        allTransitiveDependencies:
            LawyerProfileFamily._allTransitiveDependencies,
        profileId: profileId,
      );

  LawyerProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.profileId,
  }) : super.internal();

  final String profileId;

  @override
  Override overrideWith(
    FutureOr<LawyerProfile?> Function(LawyerProfileRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LawyerProfileProvider._internal(
        (ref) => create(ref as LawyerProfileRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        profileId: profileId,
      ),
    );
  }

  @override
  FutureProviderElement<LawyerProfile?> createElement() {
    return _LawyerProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LawyerProfileProvider && other.profileId == profileId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, profileId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LawyerProfileRef on FutureProviderRef<LawyerProfile?> {
  /// The parameter `profileId` of this provider.
  String get profileId;
}

class _LawyerProfileProviderElement
    extends FutureProviderElement<LawyerProfile?>
    with LawyerProfileRef {
  _LawyerProfileProviderElement(super.provider);

  @override
  String get profileId => (origin as LawyerProfileProvider).profileId;
}

String _$selectedCategoryHash() => r'80b7dddf22c543c0a0dfab3a807aec2c5f3819a7';

/// See also [SelectedCategory].
@ProviderFor(SelectedCategory)
final selectedCategoryProvider =
    AutoDisposeNotifierProvider<SelectedCategory, String?>.internal(
      SelectedCategory.new,
      name: r'selectedCategoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedCategoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedCategory = AutoDisposeNotifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
