import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class FollowLawyerButton extends ConsumerStatefulWidget {
  final String lawyerId;
  const FollowLawyerButton({super.key, required this.lawyerId});

  @override
  ConsumerState<FollowLawyerButton> createState() => _FollowLawyerButtonState();
}

class _FollowLawyerButtonState extends ConsumerState<FollowLawyerButton> {
  bool _loading = true;
  bool _submitting = false;
  bool _following = false;
  String? _profileId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final authUser = SupabaseConfig.client.auth.currentUser;
      if (authUser == null) return;
      final profile = await SupabaseConfig.client
          .from('profiles')
          .select('id')
          .eq('auth_id', authUser.id)
          .maybeSingle();
      final profileId = profile?['id']?.toString();
      if (profileId == null) return;
      final row = await SupabaseConfig.client
          .from('lawyer_followers')
          .select('lawyer_id')
          .eq('follower_id', profileId)
          .eq('lawyer_id', widget.lawyerId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _profileId = profileId;
        _following = row != null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    if (_submitting || _profileId == null) return;
    setState(() => _submitting = true);
    try {
      if (_following) {
        await SupabaseConfig.client
            .from('lawyer_followers')
            .delete()
            .eq('follower_id', _profileId!)
            .eq('lawyer_id', widget.lawyerId);
      } else {
        await SupabaseConfig.client.from('lawyer_followers').insert({
          'follower_id': _profileId,
          'lawyer_id': widget.lawyerId,
        });
      }
      if (!mounted) return;
      setState(() => _following = !_following);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _following
                ? 'ستصلك إشعارات عند إضافة المحامي مواعيد جديدة.'
                : 'تم إيقاف متابعة مواعيد هذا المحامي.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث المتابعة: ${UserFacingError.text(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateChangesProvider).value;
    if (!(user?.role == 'user' || user?.role == 'client')) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (_loading || _submitting || _profileId == null) ? null : _toggle,
        icon: _submitting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(_following ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
        label: Text(_following ? 'متابَع — إيقاف المتابعة' : 'متابعة مواعيد المحامي'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _following ? scheme.primary : scheme.onSurface,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }
}
