import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/utils/app_time_format.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatPage({super.key, required this.conversationId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  RealtimeChannel? _presenceChannel;
  String? _currentProfileId;
  bool _otherPartyOnline = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(chatControllerProvider.notifier).markRead(widget.conversationId);
      await _setupPresence();
    });
  }

  Future<void> _setupPresence() async {
    final allowed = await ref.read(chatAccessProvider(widget.conversationId).future);
    if (!allowed || !mounted) return;

    final currentUser = SupabaseConfig.client.auth.currentUser;
    if (currentUser == null || !mounted) return;
    final profile = await SupabaseConfig.client
        .from('profiles')
        .select('id')
        .eq('auth_id', currentUser.id)
        .maybeSingle();
    _currentProfileId = profile?['id']?.toString();
    if (_currentProfileId == null || !mounted) return;

    final channel = SupabaseConfig.client.channel('chat-presence:${widget.conversationId}');
    _presenceChannel = channel;
    void refreshPresence() {
      final otherId = ref
          .read(chatOtherPartyProfileIdProvider(widget.conversationId))
          .valueOrNull;
      if (otherId == null || !mounted) return;
      var online = false;
      for (final state in channel.presenceState()) {
        for (final presence in state.presences) {
          final payload = presence.payload;
          if (payload['profile_id']?.toString() == otherId) {
            online = true;
          }
        }
      }
      if (mounted && online != _otherPartyOnline) {
        setState(() => _otherPartyOnline = online);
      }
    }

    channel
        .onPresenceSync((_) => refreshPresence())
        .onPresenceJoin((_) => refreshPresence())
        .onPresenceLeave((_) => refreshPresence())
        .subscribe((status, _) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await channel.track({
              'profile_id': _currentProfileId,
              'online_at': DateTime.now().toUtc().toIso8601String(),
            });
            refreshPresence();
          }
        });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatControllerProvider.notifier)
          .send(widget.conversationId, text);
      _messageController.clear();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accessAsync = ref.watch(chatAccessProvider(widget.conversationId));

    if (accessAsync.isLoading) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(title: const Text('المحادثة')),
        body: const LoadingWidget(),
      );
    }

    if (accessAsync.hasError || accessAsync.valueOrNull != true) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(title: const Text('المحادثة')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 34,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'المحادثة غير متاحة حالياً',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'تُفتح المحادثة بين طالب الاستشارة والمحامي فقط بعد تأكيد الحجز.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final messagesAsync = ref.watch(chatMessagesProvider(widget.conversationId));
    final otherPartyNameAsync =
        ref.watch(chatOtherPartyNameProvider(widget.conversationId));
    final currentProfileIdAsync = ref.watch(currentProfileIdProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(Icons.person_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherPartyNameAsync.maybeWhen(
                      data: (name) => name ?? 'محادثة',
                      orElse: () => '...',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _otherPartyOnline ? Colors.green : scheme.outline,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _otherPartyOnline ? 'متصل الآن' : 'غير متصل',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: .45),
          ),
          Expanded(
            child: messagesAsync.when(
              data: (messages) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.p20,
                  20,
                  AppSizes.p20,
                  12,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderId == currentProfileIdAsync.value;
                  return _MessageBubble(
                    message: msg.content,
                    isMe: isMe,
                    time: msg.createdAt != null
                        ? AppTimeFormat.time12(msg.createdAt!)
                        : '...',
                  );
                },
              ),
              loading: () => const LoadingWidget(),
              error: (_, __) => Center(
                child: Text(
                  'تعذر تحميل الرسائل. حاول مرة أخرى.',
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ),
          ),
          _buildInputArea(context),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = _messageController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .7),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: .7),
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  onChanged: (_) => setState(() {}),
                  maxLines: null,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك هنا...',
                    hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hasText ? AppColors.gold : scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                boxShadow: hasText
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: .22),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: IconButton(
                tooltip: 'إرسال الرسالة',
                onPressed: hasText && !_sending ? _send : null,
                icon: _sending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: hasText
                            ? AppColors.textOnPrimary
                            : scheme.onSurfaceVariant,
                        size: 21,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = isMe ? scheme.primary : scheme.surfaceContainerHighest;
    final textColor = isMe ? scheme.onPrimary : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * .78,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft:
                    isMe ? const Radius.circular(18) : const Radius.circular(4),
                bottomRight:
                    isMe ? const Radius.circular(4) : const Radius.circular(18),
              ),
              border: isMe ? null : Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              message,
              textDirection: TextDirection.rtl,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.45),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
