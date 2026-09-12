// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payments_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$paymentsRepositoryHash() =>
    r'9022cd2e4bfc801f1b6543461b803ffb42e174ff';

/// See also [paymentsRepository].
@ProviderFor(paymentsRepository)
final paymentsRepositoryProvider =
    AutoDisposeProvider<PaymentsRepository>.internal(
      paymentsRepository,
      name: r'paymentsRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$paymentsRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PaymentsRepositoryRef = AutoDisposeProviderRef<PaymentsRepository>;
String _$paymentsControllerHash() =>
    r'af936dba821271894d567cc7ea7aa2ac62a0177e';

/// See also [PaymentsController].
@ProviderFor(PaymentsController)
final paymentsControllerProvider =
    AutoDisposeAsyncNotifierProvider<PaymentsController, void>.internal(
      PaymentsController.new,
      name: r'paymentsControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$paymentsControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PaymentsController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
