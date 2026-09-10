import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';

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

final clientWalletProvider = FutureProvider<ClientWalletSummary>((ref) async {
  final response = await SupabaseConfig.client.rpc('get_my_client_wallet');
  if (response is List && response.isNotEmpty) {
    return ClientWalletSummary.fromJson(
      Map<String, dynamic>.from(response.first as Map),
    );
  }
  if (response is Map) {
    return ClientWalletSummary.fromJson(Map<String, dynamic>.from(response));
  }
  return const ClientWalletSummary(
    availableBalance: 0,
    heldBalance: 0,
    currency: 'IQD',
  );
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
  ref.invalidate(clientWalletTopupsProvider);
  ref.invalidate(clientWalletLedgerProvider);
}
