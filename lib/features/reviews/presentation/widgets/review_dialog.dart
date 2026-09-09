import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../providers/reviews_provider.dart';

class ReviewDialog extends ConsumerStatefulWidget {
  final String bookingId;
  final String lawyerId;
  const ReviewDialog({super.key, required this.bookingId, required this.lawyerId});

  @override
  ConsumerState<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<ReviewDialog> {
  double _rating = 5.0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تقييم المحامي', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => IconButton(
                onPressed: _submitting ? null : () => setState(() => _rating = index + 1.0),
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: AppColors.secondaryLight,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.p16),
          TextField(
            controller: _commentController,
            enabled: !_submitting,
            decoration: const InputDecoration(
              hintText: 'اكتب رأيك هنا...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('إرسال التقييم'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      await ref.read(reviewControllerProvider.notifier).submitReview(
            bookingId: widget.bookingId,
            lawyerId: widget.lawyerId,
            rating: _rating,
            comment: _commentController.text,
          );

      final state = ref.read(reviewControllerProvider);
      if (!mounted) return;

      if (state.hasError) {
        throw state.error!;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UserFacingError.text(e, fallback: 'تعذر إرسال التقييم. حاول مرة أخرى.'))),
      );
    }
  }
}
