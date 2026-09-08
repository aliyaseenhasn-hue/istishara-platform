import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/models/booking_model.dart';
import '../providers/bookings_provider.dart';

class ArchivedBookingsPage extends ConsumerStatefulWidget {
  const ArchivedBookingsPage({super.key});

  @override
  ConsumerState<ArchivedBookingsPage> createState() => _ArchivedBookingsPageState();
}

class _ArchivedBookingsPageState extends ConsumerState<ArchivedBookingsPage> {
  late Future<List<dynamic>> _future;
  final Set<String> _restoring = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return [];
    final profile = await SupabaseConfig.client.from('profiles').select('id').eq('auth_id', user.id).maybeSingle();
    final id = profile?['id']?.toString();
    if (id == null) return [];
    final isLawyer = user.role == 'lawyer';
    final rows = await SupabaseConfig.client
        .from('bookings')
        .select()
        .eq(isLawyer ? 'lawyer_id' : 'user_id', id)
        .not(isLawyer ? 'archived_by_lawyer_at' : 'archived_by_user_at', 'is', null)
        .order('created_at', ascending: false);
    return (rows as List).map((row) => BookingModel.fromJson(Map<String, dynamic>.from(row as Map)).toEntity()).toList();
  }

  Future<void> _restore(String bookingId) async {
    if (_restoring.contains(bookingId)) return;
    setState(() => _restoring.add(bookingId));
    await ref.read(bookingsControllerProvider.notifier).restoreBooking(bookingId);
    if (!mounted) return;

    final result = ref.read(bookingsControllerProvider);
    if (result.hasError) {
      final message = result.error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر استعادة الاستشارة: $message')),
      );
      setState(() => _restoring.remove(bookingId));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إعادة الاستشارة إلى قائمتك.')),
    );
    setState(() {
      _restoring.remove(bookingId);
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('أرشيف الاستشارات'), centerTitle: true, leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward_rounded))),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل الأرشيف', style: TextStyle(color: scheme.onSurface)));
          final items = snapshot.data ?? const [];
          if (items.isEmpty) return Center(child: Text('لا توجد استشارات مؤرشفة حالياً', style: TextStyle(color: scheme.onSurfaceVariant)));
          return RefreshIndicator(
            onRefresh: () async {
              final next = _load();
              setState(() => _future = next);
              await next;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final booking = items[index];
                final shortId = booking.id.length > 8 ? booking.id.substring(0, 8) : booking.id;
                final restoring = _restoring.contains(booking.id);
                return Card(
                  child: ListTile(
                    title: Text('استشارة #$shortId'),
                    subtitle: Text('${booking.status} • ${booking.scheduledAt.toLocal()}'),
                    leading: const Icon(Icons.archive_outlined),
                    trailing: IconButton(
                      onPressed: restoring ? null : () => _restore(booking.id),
                      tooltip: 'إعادة إلى الاستشارات',
                      icon: restoring
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.unarchive_outlined),
                    ),
                    onTap: restoring ? null : () => context.push('/booking-details', extra: booking),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
