import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final adminUsersProvider = FutureProvider.family.autoDispose<
    List<Map<String, dynamic>>,
    ({String search, String role, String status})>((ref, f) async {
  final rows = await Supabase.instance.client.rpc('admin_list_users', params: {
    'p_search': f.search.isEmpty ? null : f.search,
    'p_role': f.role.isEmpty ? null : f.role,
    'p_status': f.status.isEmpty ? null : f.status,
  });
  return (rows as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final search = TextEditingController();
  String role = '';
  String status = '';
  String query = '';
  bool actionLoading = false;

  ({String search, String role, String status}) get filter =>
      (search: query, role: role, status: status);

  void refresh() {
    ref.invalidate(adminUsersProvider(filter));
    setState(() {});
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _setStatus(Map<String, dynamic> user) async {
    if (actionLoading) return;
    final currentStatus = user['status']?.toString() ?? '';
    final name = (user['full_name']?.toString().trim().isNotEmpty ?? false)
        ? user['full_name'].toString().trim()
        : 'المستخدم';

    if (currentStatus == 'active') {
      final controller = TextEditingController();
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إيقاف الحساب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'سيُمنع $name من تنفيذ العمليات داخل المنصة، وإذا كان محامياً فسيختفي من الحجز العام وتُخفى مواعيده المتاحة.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'سبب الإيقاف (إلزامي)',
                  hintText: 'اكتب سبباً واضحاً يظهر للمستخدم في الإشعار',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('سبب الإيقاف إلزامي')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('تأكيد الإيقاف'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || !mounted) return;
      await _executeStatusChange(
        userId: user['id'].toString(),
        newStatus: 'blocked',
        reason: reason,
        successMessage: 'تم إيقاف حساب $name فعلياً.',
      );
      return;
    }

    if (currentStatus == 'blocked') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إعادة تفعيل الحساب'),
          content: Text(
            'هل تريد إعادة تفعيل حساب $name؟ سيستطيع استخدام خدمات المنصة مجدداً فور اعتماد القرار.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('تراجع'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('إعادة التفعيل'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _executeStatusChange(
        userId: user['id'].toString(),
        newStatus: 'active',
        reason: null,
        successMessage: 'تمت إعادة تفعيل حساب $name.',
      );
    }
  }

  Future<void> _executeStatusChange({
    required String userId,
    required String newStatus,
    required String? reason,
    required String successMessage,
  }) async {
    try {
      setState(() => actionLoading = true);
      await Supabase.instance.client.rpc(
        'admin_set_user_status',
        params: {
          'p_user_id': userId,
          'p_new_status': newStatus,
          'p_reason': reason,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider(filter));
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        actions: [
          IconButton(
            onPressed: actionLoading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: search,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'بحث بالاسم أو الهاتف أو البريد',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    query = search.text.trim();
                    refresh();
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(
                          labelText: 'نوع الحساب',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('الكل')),
                          DropdownMenuItem(
                              value: 'user', child: Text('طالب استشارة')),
                          DropdownMenuItem(
                              value: 'lawyer', child: Text('محامي')),
                          DropdownMenuItem(
                              value: 'admin', child: Text('إدارة')),
                          DropdownMenuItem(
                              value: 'moderator', child: Text('مشرف')),
                        ],
                        onChanged: (v) {
                          role = v ?? '';
                          refresh();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'الحالة',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('الكل')),
                          DropdownMenuItem(value: 'active', child: Text('فعال')),
                          DropdownMenuItem(
                              value: 'blocked', child: Text('موقوف')),
                          DropdownMenuItem(
                              value: 'pending', child: Text('قيد الانتظار')),
                          DropdownMenuItem(
                              value: 'deleted', child: Text('محذوف')),
                        ],
                        onChanged: (v) {
                          status = v ?? '';
                          refresh();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'تعذر تحميل المستخدمين: $e',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('لا يوجد مستخدمون'))
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(adminUsersProvider(filter));
                        await ref.read(adminUsersProvider(filter).future);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _userTile(items[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> u) {
    final nameValue = u['full_name']?.toString().trim() ?? '';
    final name = nameValue.isEmpty ? 'بدون اسم' : nameValue;
    final userRole = u['role']?.toString() ?? '';
    final userStatus = u['status']?.toString() ?? '';
    final canManage =
        (userRole == 'user' || userRole == 'lawyer') &&
            (userStatus == 'active' || userStatus == 'blocked');

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(name.characters.first)),
        title: Text(name),
        subtitle: Text(
          '${_roleLabel(userRole)} • ${u['phone'] ?? u['email'] ?? 'لا توجد بيانات اتصال'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(label: Text(_statusLabel(userStatus))),
            if (canManage)
              PopupMenuButton<String>(
                enabled: !actionLoading,
                onSelected: (_) => _setStatus(u),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: userStatus == 'active' ? 'block' : 'activate',
                    child: Row(
                      children: [
                        Icon(
                          userStatus == 'active'
                              ? Icons.block_rounded
                              : Icons.check_circle_outline_rounded,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          userStatus == 'active'
                              ? 'إيقاف الحساب'
                              : 'إعادة التفعيل',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String v) => {
        'user': 'طالب استشارة',
        'lawyer': 'محامي',
        'admin': 'إدارة',
        'moderator': 'مشرف',
      }[v] ??
      v;

  String _statusLabel(String v) => {
        'active': 'فعال',
        'blocked': 'موقوف',
        'pending': 'قيد الانتظار',
        'deleted': 'محذوف',
      }[v] ??
      v;
}
