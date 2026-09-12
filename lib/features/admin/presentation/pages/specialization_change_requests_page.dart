import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/services/private_storage_reference.dart';

class SpecializationChangeRequestsPage extends ConsumerStatefulWidget {
  const SpecializationChangeRequestsPage({super.key});

  @override
  ConsumerState<SpecializationChangeRequestsPage> createState() => _SpecializationChangeRequestsPageState();
}

class _SpecializationChangeRequestsPageState extends ConsumerState<SpecializationChangeRequestsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await SupabaseConfig.client
        .from('specialization_change_requests')
        .select('id,lawyer_id,requested_specializations,status,union_id_card_url,created_at,review_note')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final result = <Map<String, dynamic>>[];
    for (final item in rows as List) {
      final request = Map<String, dynamic>.from(item as Map);
      final profile = await SupabaseConfig.client
          .from('lawyer_profiles')
          .select('full_name,license_number')
          .eq('profile_id', request['lawyer_id'])
          .maybeSingle();
      request['lawyer_name'] = profile?['full_name'] ?? 'محامي';
      request['license_number'] = profile?['license_number'];
      request['union_id_card_url'] = await PrivateStorageReference.resolve(
        SupabaseConfig.client,
        request['union_id_card_url']?.toString(),
      );
      result.add(request);
    }
    return result;
  }

  Future<void> _review(String id, bool approved) async {
    final controller = TextEditingController();
    final note = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approved ? 'الموافقة على الطلب' : 'رفض الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              approved
                  ? 'راجع هوية النقابة والتخصصات المطلوبة قبل الاعتماد. يمكنك إضافة ملاحظة إدارية اختيارية.'
                  : 'اكتب سبب الرفض بوضوح ليعرف المحامي ما المطلوب تعديله قبل إعادة الطلب.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: approved ? 'ملاحظة (اختياري)' : 'سبب الرفض (إلزامي)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (!approved && value.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('سبب رفض طلب تغيير التخصص إلزامي.')),
                );
                return;
              }
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;

    try {
      await SupabaseConfig.client.rpc(
        'review_specialization_change',
        params: {
          'p_request_id': id,
          'p_approved': approved,
          'p_note': note,
        },
      );
      if (!mounted) return;
      setState(() => _future = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approved ? 'تمت الموافقة على الطلب وتحديث التخصص.' : 'تم رفض الطلب وإرسال السبب للمحامي.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات تغيير التخصص'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('تعذر تحميل الطلبات: ${snapshot.error}'));
          }

          final rows = snapshot.data ?? <Map<String, dynamic>>[];
          if (rows.isEmpty) {
            return const Center(child: Text('لا توجد طلبات تغيير تخصص معلقة.'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final specialties = row['requested_specializations'];
                final specialtyText = specialties is List
                    ? specialties.map((e) => e.toString()).join('، ')
                    : specialties?.toString() ?? '-';
                final idCardUrl = row['union_id_card_url']?.toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['lawyer_name']?.toString() ?? 'محامي',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        if (row['license_number'] != null)
                          Text('رقم الإجازة: ${row['license_number']}'),
                        const SizedBox(height: 8),
                        Text('التخصصات المطلوبة: $specialtyText'),
                        const SizedBox(height: 12),
                        if (idCardUrl != null && idCardUrl.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (_) => Dialog(
                                  child: InteractiveViewer(
                                    child: Image.network(
                                      idCardUrl,
                                      errorBuilder: (_, __, ___) => const Padding(
                                        padding: EdgeInsets.all(30),
                                        child: Text('تعذر فتح هوية النقابة.'),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.badge_outlined),
                            label: const Text('عرض هوية النقابة'),
                          )
                        else
                          const Text(
                            'لا توجد هوية نقابة قابلة للمراجعة.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: idCardUrl == null || idCardUrl.isEmpty
                                    ? null
                                    : () => _review(row['id'].toString(), true),
                                icon: const Icon(Icons.check),
                                label: const Text('موافقة'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _review(row['id'].toString(), false),
                                icon: const Icon(Icons.close),
                                label: const Text('رفض'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
