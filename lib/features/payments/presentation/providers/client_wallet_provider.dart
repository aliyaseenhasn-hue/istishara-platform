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
  final authUser = SupabaseConfig.client.auth.currentUser;
  if (authUser == null) {
    yield _emptyClientWallet;
    return;
  }

  final profile = await SupabaseConfig.client
      .from('profiles')
      .select('id')
      .eq('auth_id', authUser.id)
      .maybeSingle();
  final profileId = profile?['id']?.toString();
  if (profileId == null || profileId.isEmpty) {
    yield _emptyClientWallet;
    return;
  }

  // Load a stable snapshot first. A temporary Realtime/WebSocket failure must
  // not make the wallet balance disappear or expose a channel error to users.
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
      // Keep the last known wallet usable, refresh it through PostgREST, then
      // retry Realtime with a short bounded backoff.
      try {
        yield await _loadClientWallet(profileId);
      } catch (_) {
        // If the fallback request also fails, preserve the last emitted value.
      }
      await Future<void>.delayed(Duration(seconds: retrySeconds));
      retrySeconds = retrySeconds >= 15 ? 15 : retrySeconds * 2;
    }
  }
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
