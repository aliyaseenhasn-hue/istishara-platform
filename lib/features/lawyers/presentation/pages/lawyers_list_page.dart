import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/legal_specializations.dart';
import '../providers/lawyers_provider.dart';
import '../../data/repositories/lawyers_repository_impl.dart';
import '../../domain/entities/lawyer_profile.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../shared/widgets/loading_widget.dart';

String _normalizeArabicSearch(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll(RegExp(r'[ـ\u064B-\u065F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool _matchesLawyerSearch(LawyerProfile lawyer, String query) {
  final normalizedQuery = _normalizeArabicSearch(query);
  if (normalizedQuery.isEmpty) return true;
  final searchable = _normalizeArabicSearch([
    lawyer.fullName ?? '',
    ...lawyer.specializations,
    lawyer.bio ?? '',
    ...lawyer.services.map((service) => service.title),
  ].join(' '));
  return normalizedQuery.split(' ').where((term) => term.isNotEmpty).every(searchable.contains);
}

bool _matchesLawyerCategory(LawyerProfile lawyer, String category) {
  final wanted = _normalizeArabicSearch(category);
  return lawyer.specializations.any((value) {
    final actual = _normalizeArabicSearch(value);
    return actual == wanted || actual.contains(wanted) || wanted.contains(actual);
  });
}

class LawyersListPage extends ConsumerStatefulWidget {
  const LawyersListPage({super.key});

  @override
  ConsumerState<LawyersListPage> createState() => _LawyersListPageState();
}

class _LawyersListPageState extends ConsumerState<LawyersListPage> {
  static const _pageSize = 20;
  late final ScrollController _scrollController;
  late final LawyersRepositoryImpl _repository;
  final TextEditingController _searchController = TextEditingController();
  final List<LawyerProfile> _lawyers = [];
  String _query = '';
  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _repository = LawyersRepositoryImpl(SupabaseConfig.client);
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || !_hasMore) return;
    if (_scrollController.position.extentAfter < 600) _loadMore();
  }

  Future<void> _loadMore({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _offset = 0;
      _hasMore = true;
      _lawyers.clear();
    }
    if (!_hasMore) return;
    setState(() => _loading = true);
    try {
      final batch = await _repository.getLawyers(limit: _pageSize, offset: _offset);
      if (!mounted) return;
      setState(() {
        _lawyers.addAll(batch);
        _offset += batch.length;
        _hasMore = batch.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_lawyers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحميل المحامين. حاول مرة أخرى.')));
      }
    }
  }

  Future<void> _loadRemainingLawyers() async {
    while (mounted && _hasMore) {
      final previousOffset = _offset;
      await _loadMore();
      if (_offset <= previousOffset) break;
    }
  }

  List<LawyerProfile> _filtered(String? category) {
    final list = _lawyers.where((lawyer) {
      final searchMatch = _matchesLawyerSearch(lawyer, _query);
      final categoryMatch = category == null || category.trim().isEmpty || _matchesLawyerCategory(lawyer, category);
      return searchMatch && categoryMatch;
    }).toList();
    list.sort((a, b) {
      if (a.availability && !b.availability) return -1;
      if (!a.availability && b.availability) return 1;
      final rating = b.rating.compareTo(a.rating);
      return rating != 0 ? rating : b.reviewCount.compareTo(a.reviewCount);
    });
    return list;
  }

  void _setSearch(String value) {
    setState(() => _query = value);
    if (value.trim().length >= 2 && _hasMore && !_loading) unawaited(_loadRemainingLawyers());
  }

  void _clearSearch() {
    _searchController.clear();
    _setSearch('');
  }

  void _selectCategory(String? value) {
    ref.read(selectedCategoryProvider.notifier).setCategory(value);
    if (_hasMore && !_loading) unawaited(_loadRemainingLawyers());
  }

  Future<void> _showSpecializationPicker(String? selectedCategory) async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _SpecializationPicker(selectedCategory: selectedCategory),
    );
    if (!mounted || selection == null) return;
    final category = selection == _SpecializationPicker.allValue ? null : selection;
    if (category != selectedCategory) _selectCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final lawyers = _filtered(selectedCategory);
    final title = selectedCategory == null ? 'دليل المحامين' : 'القانون ${selectedCategory == 'أحوال شخصية' ? 'للأحوال الشخصية' : selectedCategory}';

    return Scaffold(
      backgroundColor: scheme.surface,
      body: RefreshIndicator(
        onRefresh: () => _loadMore(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _DirectoryHeader(onNotifications: () => context.push('/notifications'))),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              sliver: SliverList(delegate: SliverChildListDelegate([
                Text(title, textAlign: TextAlign.right, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('ابحث عن نخبة المحامين والمستشارين القانونيين المعتمدين.', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.5)),
                const SizedBox(height: 16),
                _SearchField(controller: _searchController, onChanged: _setSearch, onClear: _clearSearch),
                const SizedBox(height: 12),
                _FilterPanel(
                  selectedCategory: selectedCategory,
                  resultCount: lawyers.length,
                  onSelect: _selectCategory,
                  onShowAll: () => _showSpecializationPicker(selectedCategory),
                ),
                const SizedBox(height: 20),
              ])),
            ),
            if (_lawyers.isEmpty && _loading)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(50), child: Center(child: LoadingWidget())))
            else if (_lawyers.isEmpty && !_loading)
              const SliverToBoxAdapter(child: _Message(text: 'لا يوجد محامون موثقون حالياً'))
            else if (lawyers.isEmpty)
              SliverToBoxAdapter(
                child: _NoResults(
                  query: _query,
                  hasCategory: selectedCategory != null,
                  onClear: () {
                    _clearSearch();
                    if (selectedCategory != null) _selectCategory(null);
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: lawyers.length,
                  itemBuilder: (context, index) => _LawyerCard(lawyer: lawyers[index]),
                ),
              ),
            if (_loading && _lawyers.isNotEmpty)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 100), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))))
            else
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _DirectoryHeader extends StatelessWidget {
  final VoidCallback onNotifications;
  const _DirectoryHeader({required this.onNotifications});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(18, MediaQuery.paddingOf(context).top + 8, 18, 10),
      decoration: BoxDecoration(color: scheme.surface, border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      child: Row(textDirection: TextDirection.rtl, children: [
        IconButton(tooltip: 'التنبيهات', onPressed: onNotifications, icon: Icon(Icons.notifications_none_rounded, color: scheme.onSurface)),
        const Spacer(),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('استشارة', style: TextStyle(color: scheme.primary, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(width: 9),
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.primary.withValues(alpha: .28)),
              boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: .12), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.asset('assets/icons/app_icon.png', fit: BoxFit.cover)),
          ),
        ]),
        const Spacer(),
        IconButton(tooltip: 'رجوع', onPressed: () => context.pop(), icon: Icon(Icons.arrow_forward_rounded, color: scheme.onSurface)),
      ]),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchField({required this.controller, required this.onChanged, required this.onClear});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textDirection: TextDirection.rtl,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: 'البحث عن محامٍ',
        hintText: 'اكتب الاسم أو التخصص أو نوع الخدمة',
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(tooltip: 'مسح البحث', onPressed: onClear, icon: Icon(Icons.clear_rounded, color: scheme.onSurfaceVariant)),
        fillColor: scheme.surfaceContainerLowest,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 1.7)),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final String? selectedCategory;
  final int resultCount;
  final ValueChanged<String?> onSelect;
  final VoidCallback onShowAll;
  const _FilterPanel({required this.selectedCategory, required this.resultCount, required this.onSelect, required this.onShowAll});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const values = <String?>[null, 'أحوال شخصية', 'تجاري', 'جنائي', 'مدني'];
    final commonValues = selectedCategory == null || values.contains(selectedCategory) ? values : [...values, selectedCategory];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(textDirection: TextDirection.rtl, children: [
        Text('تصفية حسب التخصص', style: TextStyle(color: scheme.onSurface, fontSize: 12, fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('$resultCount نتيجة', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onShowAll,
          icon: const Icon(Icons.tune_rounded, size: 17),
          label: Text(selectedCategory == null ? 'عرض كل التخصصات' : 'التخصص المحدد: $selectedCategory'),
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.primary,
            side: BorderSide(color: selectedCategory == null ? scheme.outlineVariant : scheme.primary),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 9),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(children: commonValues.map((value) {
          final selected = value == selectedCategory;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 7),
            child: ChoiceChip(
              selected: selected,
              avatar: selected ? Icon(Icons.check_rounded, size: 16, color: scheme.onPrimaryContainer) : null,
              label: Text(value ?? 'الكل'),
              onSelected: (_) => onSelect(value),
              selectedColor: scheme.primaryContainer,
              backgroundColor: scheme.surfaceContainerLowest,
              side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
              labelStyle: TextStyle(color: selected ? scheme.onPrimaryContainer : scheme.onSurface, fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }).toList()),
      ),
    ]);
  }
}

class _SpecializationPicker extends StatelessWidget {
  static const allValue = '__all__';
  final String? selectedCategory;
  const _SpecializationPicker({required this.selectedCategory});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .78),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Row(textDirection: TextDirection.rtl, children: [
              Expanded(child: Text('اختر التخصص القانوني', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900))),
              IconButton(tooltip: 'إغلاق', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              children: [
                _SpecializationOption(label: 'جميع التخصصات', selected: selectedCategory == null, onTap: () => Navigator.pop(context, allValue)),
                ...LegalSpecializations.all.map((value) => _SpecializationOption(label: value, selected: selectedCategory == value, onTap: () => Navigator.pop(context, value))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _SpecializationOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SpecializationOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onTap,
        selected: selected,
        selectedTileColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(label, textAlign: TextAlign.right, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
        trailing: Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? scheme.primary : scheme.outline),
      ),
    );
  }
}

class _LawyerCard extends StatelessWidget {
  final LawyerProfile lawyer;
  const _LawyerCard({required this.lawyer});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = lawyer.avatarUrl;
    final hasAvatar = avatar != null && avatar.isNotEmpty;
    final tags = lawyer.specializations.isNotEmpty ? lawyer.specializations.take(2).toList() : ['قانون عام'];
    return Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.outlineVariant)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [InkWell(onTap: () => context.push('/lawyer-details/${lawyer.profileId}'), borderRadius: BorderRadius.circular(12), child: Row(textDirection: TextDirection.rtl, crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 66, height: 66, decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surfaceContainerHighest, border: Border.all(color: scheme.primary.withValues(alpha: .55), width: 1.5), image: hasAvatar ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover) : null), child: hasAvatar ? null : Icon(Icons.person_rounded, color: scheme.onSurfaceVariant, size: 32)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Row(textDirection: TextDirection.rtl, children: [Expanded(child: Text(lawyer.fullName ?? 'محامي', textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurface, fontSize: 16, fontWeight: FontWeight.w900))), if (lawyer.verified) ...[const SizedBox(width: 5), Icon(Icons.verified_rounded, color: scheme.primary, size: 17)]]), const SizedBox(height: 4), Text(lawyer.specializations.isNotEmpty ? 'محامي ${tags.first}' : 'محامي ومستشار قانوني', textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.primary, fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.end, children: [Icon(Icons.star_rounded, color: scheme.tertiary, size: 16), const SizedBox(width: 2), Text(lawyer.rating.toStringAsFixed(1), style: TextStyle(color: scheme.onSurface, fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(width: 7), Text('تقييم المحامي', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10))])]))])), const SizedBox(height: 12), Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 6, children: tags.map<Widget>((tag) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(8)), child: Text(tag.toString(), style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 9, fontWeight: FontWeight.w600)))).toList()), const SizedBox(height: 10), Row(textDirection: TextDirection.rtl, children: [Icon(Icons.location_on_outlined, color: scheme.onSurfaceVariant, size: 15), const SizedBox(width: 4), Text('العراق', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10)), const Spacer(), Icon(Icons.payments_outlined, color: scheme.onSurfaceVariant, size: 15), const SizedBox(width: 4), Text('${(lawyer.consultationPrice ?? 0).toStringAsFixed(0)} د.ع / الجلسة', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w600))]), const SizedBox(height: 12), SizedBox(height: 46, child: ElevatedButton(onPressed: () => context.push('/lawyer-details/${lawyer.profileId}'), style: ElevatedButton.styleFrom(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary, textStyle: const TextStyle(fontWeight: FontWeight.w800), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('عرض الملف الشخصي')))]));
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  final bool hasCategory;
  final VoidCallback onClear;
  const _NoResults({required this.query, required this.hasCategory, required this.onClear});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 45, 24, 100),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.person_search_outlined, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('لا توجد نتائج مطابقة', style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16)),
            if (query.trim().isNotEmpty || hasCategory) ...[
              const SizedBox(height: 6),
              Text(query.trim().isEmpty ? 'لا يوجد محامون مطابقون للتخصص المحدد.' : 'لم نجد محامياً يطابق «${query.trim()}» مع الفلاتر الحالية.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5, fontSize: 12)),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: onClear, icon: const Icon(Icons.clear_rounded), label: const Text('مسح البحث والفلاتر')),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  const _Message({required this.text});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5))));
}
