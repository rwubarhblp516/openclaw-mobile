import 'package:flutter/material.dart';
import 'package:openclaw_mobile/src/ui/theme.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.timestamp,
    this.isMine = false,
    this.showTail = true,
    this.status,
  });

  final String message;
  final String? timestamp;
  final bool isMine;
  final bool showTail;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final alignment = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMine ? AppColors.bubbleOutgoing : AppColors.bubbleIncoming;
    final bubbleGradient = isMine
        ? const LinearGradient(
            colors: [AppColors.bubbleOutgoing, AppColors.bubbleOutgoingEdge],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine && showTail)
              const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxBubbleWidth = constraints.maxWidth * 0.78;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                    child: CustomPaint(
                      painter: showTail
                          ? _BubbleTailPainter(
                              color: bubbleColor,
                              isMine: isMine,
                            )
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleGradient == null ? bubbleColor : null,
                          gradient: bubbleGradient,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMine ? 18 : 6),
                            bottomRight: Radius.circular(isMine ? 6 : 18),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: isMine ? AppColors.bubbleOutgoingEdge : AppColors.borderSubtle,
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: alignment,
                          children: [
                            Text(
                              message,
                              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                            ),
                            if (timestamp != null || status != null)
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.xs),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (timestamp != null)
                                      Text(
                                        timestamp!,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textFaint,
                                        ),
                                      ),
                                    if (timestamp != null && status != null)
                                      const SizedBox(width: AppSpacing.xs),
                                    if (status != null)
                                      Text(
                                        status!,
                                        style: AppTypography.caption.copyWith(
                                          color: isMine
                                              ? AppColors.accent
                                              : AppColors.textFaint,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (isMine && showTail)
              const SizedBox(width: AppSpacing.xs),
          ],
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color, required this.isMine});

  final Color color;
  final bool isMine;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    if (isMine) {
      path.moveTo(size.width - 2, size.height - 18);
      path.quadraticBezierTo(
        size.width + 6,
        size.height - 12,
        size.width - 2,
        size.height - 2,
      );
      path.quadraticBezierTo(
        size.width - 10,
        size.height + 2,
        size.width - 14,
        size.height - 8,
      );
    } else {
      path.moveTo(2, size.height - 18);
      path.quadraticBezierTo(
        -6,
        size.height - 12,
        2,
        size.height - 2,
      );
      path.quadraticBezierTo(
        10,
        size.height + 2,
        14,
        size.height - 8,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isMine != isMine;
  }

  @override
  bool shouldRebuildSemantics(covariant _BubbleTailPainter oldDelegate) => false;
}
