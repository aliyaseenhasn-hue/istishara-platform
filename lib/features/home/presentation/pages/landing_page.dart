import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../lawyers/domain/entities/lawyer_profile.dart';
import '../../../lawyers/presentation/providers/lawyers_provider.dart';

const _navy = Color(0xFF18304F);
const _gold = Color(0xFFC9A84C);
const _goldSoft = Color(0xFFE8D9AD);
const _offWhite = Color(0xFFF8F7F4);
const _text = Color(0xFF24364D);
const _textMid = Color(0xFF65748A);

class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lawyersAsync = ref.watch(lawyersListProvider);
    return Scaffold(
      backgroundColor: _offWhite,
      body: Directionality(textDirection: TextDirection.rtl, child: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true, backgroundColor: _offWhite, surfaceTintColor: _offWhite, elevation: 0,
          titleSpacing: 20,
          title: const Text('استشارة', style: TextStyle(color: _navy, fontWeight: FontWeight.w900, fontSize: 21)),
          actions: [
            TextButton(onPressed: () => context.push('/login'), child: const Text('تسجيل الدخول', style: TextStyle(color: _navy, fontWeight: FontWeight.w700, fontSize: 13))),
            Padding(padding: const EdgeInsets.only(left: 14, right: 4, top: 8, bottom: 8), child: FilledButton(onPressed: () => context.push('/signup'), style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _navy, padding: const EdgeInsets.symmetric(horizontal: 14)), child: const Text('إنشاء حساب', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)))),
          ],
        ),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(22, 28, 22, 34), child: Container(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5E1D7))),
          child: Column(children: [
            Container(width: 48, height: 4, decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(9))),
            const SizedBox(height: 20),
            const Text('استشارتك القانونية تبدأ من هنا', textAlign: TextAlign.center, style: TextStyle(color: _navy, fontSize: 29, height: 1.25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('تواصل مع محامٍ موثوق واحصل على التوجيه القانوني الذي تحتاجه.', textAlign: TextAlign.center, style: TextStyle(color: _textMid, fontSize: 15, height: 1.6)),
            const SizedBox(height: 22),
            ClipRRect(borderRadius: BorderRadius.circular(18), child: SvgPicture.asset('assets/landing/lawyer_client.svg', width: 300, height: 190, fit: BoxFit.contain)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: () => context.push('/signup'), style: FilledButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white), child: const Text('اطلب استشارة الآن', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)))),
          ]),
        ))),
        SliverToBoxAdapter(child: _sectionTitle('كيف تعمل استشارة؟')),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E1D7))),
          child: Row(children: const [
            Expanded(child: _Step(number: '1', title: 'اختر محاميًا', icon: Icons.person_search_outlined)),
            Expanded(child: _Step(number: '2', title: 'أرسل طلبك', icon: Icons.edit_note_outlined)),
            Expanded(child: _Step(number: '3', title: 'تابع استشارتك', icon: Icons.chat_bubble_outline)),
          ]),
        ))),
        SliverToBoxAdapter(child: _sectionTitle('محامون موثوقون')),
        lawyersAsync.when(
          loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (lawyers) {
            final verified = lawyers.where((lawyer) => lawyer.verified).take(6).toList();
            if (verified.isEmpty) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('سيظهر المحامون الموثوقون هنا قريبًا.', style: TextStyle(color: _textMid)))));
            return SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: SliverList(delegate: SliverChildListDelegate([
              ...verified.map((lawyer) => _LawyerCard(lawyer: lawyer)),
              const SizedBox(height: 4),
              Center(child: TextButton(onPressed: () => context.push('/lawyers'), child: const Text('عرض جميع المحامين'))),
            ])));
          },
        ),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 26, 20, 42), child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: const Color(0xFFF0ECE1), borderRadius: BorderRadius.circular(20)),
          child: const Column(children: [
            Text('لست مضطرًا للبحث وحدك', textAlign: TextAlign.center, style: TextStyle(color: _navy, fontSize: 21, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('ابدأ بخطوة بسيطة واختر المحامي المناسب لك.', textAlign: TextAlign.center, style: TextStyle(color: _textMid, fontSize: 14, height: 1.5)),
          ]),
        ))),
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(22), child: Center(child: Text('استشارة © جميع الحقوق محفوظة', style: TextStyle(color: _textMid, fontSize: 12))))),
      ])),
    );
  }

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.fromLTRB(20, 28, 20, 14), child: Text(title, style: const TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w900)));
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.icon});
  final String number; final String title; final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(color: _goldSoft.withValues(alpha: .55), borderRadius: BorderRadius.circular(13)), alignment: Alignment.center, child: Icon(icon, color: _navy, size: 23)),
    const SizedBox(height: 8),
    Text('$number. $title', textAlign: TextAlign.center, style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 12)),
  ]));
}

class _LawyerCard extends StatelessWidget {
  const _LawyerCard({required this.lawyer});
  final LawyerProfile lawyer;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 10), elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E1D7))), child: InkWell(
    borderRadius: BorderRadius.circular(16), onTap: () => context.push('/lawyers/${lawyer.id}'), child: Padding(padding: const EdgeInsets.all(13), child: Row(children: [
      CircleAvatar(radius: 27, backgroundImage: lawyer.avatarUrl != null && lawyer.avatarUrl!.isNotEmpty ? NetworkImage(lawyer.avatarUrl!) : null, child: lawyer.avatarUrl == null || lawyer.avatarUrl!.isEmpty ? const Icon(Icons.person, color: _navy) : null),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(lawyer.fullName ?? 'محامٍ موثوق', style: const TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)), const Icon(Icons.verified, color: _gold, size: 18)]), const SizedBox(height: 4), Text(lawyer.specializations.isNotEmpty ? lawyer.specializations.join('، ') : 'محامٍ', style: const TextStyle(color: _textMid, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)])),
      const Icon(Icons.chevron_left, color: _textMid),
    ]))));
}
