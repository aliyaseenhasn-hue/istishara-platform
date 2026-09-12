// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_management_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$paymentManagementHash() => r'1759eda9c0afbd5b53c18594baee15e6c6edfb25';

/// See also [PaymentManagement].
@ProviderFor(PaymentManagement)
final paymentManagementProvider =
    AutoDisposeAsyncNotifierProvider<PaymentManagement, List<Payment>>.internal(
      PaymentManagement.new,
      name: r'paymentManagementProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$paymentManagementHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PaymentManagement = AutoDisposeAsyncNotifier<List<Payment>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
