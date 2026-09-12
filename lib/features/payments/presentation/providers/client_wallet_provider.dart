import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class ClientWalletSummary {
  final double availableBalance;
  final double heldBalance;
  final String currency;

  const ClientWalletSummary({
    required this.availableBalance,
    required this.heldBalance,
    required this.currency,
  });

  factory ClientWalletSummary.fromJson(Map<String, dynamic> json) {
    return ClientWalletSummary(
      availableBalance: double.tryParse('${json['available_balance'] ?? 0}') ?? 0,
      heldBalance: double.tryParse('${json['held_balance'] ?? 0}') ?? 0,
      currency: json['currency']?.toString() ?? 'IQD',
    );
  }
}

const _emptyClientWallet = ClientWalletSummary(
  availableBalance: 0,
  heldBalance: 0,
  currency: 'IQD',
);

Future<ClientWalletSummary> _loadClientWallet(String profileId) async {
  final row = await SupabaseConfig.client
      .from('client_wallets')
      .select('available_balance,held_balance,currency')
      .eq('user_id', profileId)
      .maybeSingle();
  if (row == null) return _emptyClientWallet;
  return ClientWalletSummary.fromJson(Map<String, dynamic>.from(row));
}

final clientWalletProvider = StreamProvider<ClientWalletSummary>((ref) async* {
  final profileId = await ref.watch(currentProfileIdProvider.future);
  if (profileId == null || profileId.isEmpty) {
    yield _emptyClientWallet;
    return;
  }

  yield await _loadClientWallet(profileId);

  var retrySeconds = 2;
  while (true) {
    try {
      await for (final rows in SupabaseConfig.client
          .from('client_wallets')
          .stream(primaryKey: ['user_id'])
          .eq('user_id', profileId)) {
        retrySeconds = 2;
        if (rows.isEmpty) {
          yield _emptyClientWallet;
        } else {
          yield ClientWalletSummary.fromJson(
            Map<String, dynamic>.from(rows.first),
          );
        }
      }
    } catch (_) {
      try {
        yield await _loadClientWallet(profileId);
      } catch (_) {
        // Preserve the most recently emitted value if both transports fail.
      }
      await Future<void>.delayed(Duration(seconds: retrySeconds));
      retrySeconds = retrySeconds >= 15 ? 15 : retrySeconds * 2;
    }
  }
});

final financialPolicyProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final raw = await SupabaseConfig.client.rpc('get_financial_policy_summary');
  if (raw is List && raw.isNotEmpty) {
    return Map<String, dynamic>.from(raw.first as Map);
  }
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
});

final clientWalletWithdrawalsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseConfig.client
      .from('client_wallet_withdrawal_requests')
      .select(
        'id,amount,transfer_fee,net_amount,currency,status,provider_type,'
        'account_holder_name,account_number,bank_name,financial_policy_version,'
        'processing_min_business_days,processing_max_business_days,'
        'processing_deadline_at,provider_reference,rejection_reason,admin_note,requested_at',
      )
      .order('requested_at', ascending: false)
      .limit(30);
  return (rows as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList(growable: false);
});

final clientWalletTopupsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseConfig.client
      .from('client_wallet_topups')
      .select(
        'id,amount,currency,transaction_number,status,review_deadline_at,admin_note,created_at',
      )
      .order('created_at', ascending: false)
      .limit(30);
  return (rows as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList(growable: false);
});

final clientWalletLedgerProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseConfig.client
      .from('client_wallet_ledger')
      .select('id,amount,entry_type,balance_after,metadata,created_at')
      .order('created_at', ascending: false)
      .limit(50);
  return (rows as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList(growable: false);
});

void invalidateClientWallet(Ref ref) {
  ref.invalidate(clientWalletProvider);
  ref.invalidate(financialPolicyProvider);
  ref.invalidate(clientWalletWithdrawalsProvider);
  ref.invalidate(clientWalletTopupsProvider);
  ref.invalidate(clientWalletLedgerProvider);
}
