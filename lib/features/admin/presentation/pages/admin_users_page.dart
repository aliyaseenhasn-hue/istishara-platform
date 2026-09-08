import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final adminUsersProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, ({String search, String role, String status})>((ref, f) async {
  final rows = await Supabase.instance.client.rpc('admin_list_users', params: {
    'p_search': f.search.isEmpty ? null : f.search,
    'p_role': f.role.isEmpty ? null : f.role,
    'p_status': f.status.isEmpty ? null : f.status,
  });
  return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  ({String search, String role, String status}) get filter => (search: query, role: role, status: status);

  void refresh() {
    ref.invalidate(adminUsersProvider(filter));
    setState(() {});
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider(filter));
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستخدمين'), actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(controller: search, textInputAction: TextInputAction.search, decoration: const InputDecoration(labelText: 'بحث بالاسم أو الهاتف أو البريد', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onSubmitted: (_) { query = search.text.trim(); refresh(); }),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: DropdownButtonFormField<String>(initialValue: role, decoration: const InputDecoration(labelText: 'نوع الحساب', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: '', child: Text('الكل')), DropdownMenuItem(value: 'user', child: Text('طالب استشارة')), DropdownMenuItem(value: 'lawyer', child: Text('محامي')), DropdownMenuItem(value: 'admin', child: Text('إدارة')), DropdownMenuItem(value: 'moderator', child: Text('مشرف'))], onChanged: (v) { role = v ?? ''; refresh(); })),
                    const SizedBox(width: 8),
                    Expanded(child: DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: '', child: Text('الكل')), DropdownMenuItem(value: 'active', child: Text('فعال')), DropdownMenuItem(value: 'blocked', child: Text('موقوف')), DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')), DropdownMenuItem(value: 'deleted', child: Text('محذوف'))], onChanged: (v) { status = v ?? ''; refresh(); })),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر تحميل المستخدمين: $e', textAlign: TextAlign.center))),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('لا يوجد مستخدمون'))
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(adminUsersProvider(filter)),
                      child: ListView.separated(itemCount: items.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) => _userTile(items[i])),
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
    final role = u['role']?.toString() ?? '';
    final status = u['status']?.toString() ?? '';
    return ListTile(leading: CircleAvatar(child: Text(name.characters.first)), title: Text(name), subtitle: Text('${_roleLabel(role)} • ${u['phone'] ?? u['email'] ?? 'لا توجد بيانات اتصال'}'), trailing: Chip(label: Text(_statusLabel(status))));
  }

  String _roleLabel(String v) => {'user': 'طالب استشارة', 'lawyer': 'محامي', 'admin': 'إدارة', 'moderator': 'مشرف'}[v] ?? v;
  String _statusLabel(String v) => {'active': 'فعال', 'blocked': 'موقوف', 'pending': 'قيد الانتظار', 'deleted': 'محذوف'}[v] ?? v;
}
