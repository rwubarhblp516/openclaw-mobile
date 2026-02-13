import 'package:flutter/material.dart';
import 'package:openclaw_mobile/src/ui/theme.dart';
import 'package:openclaw_mobile/src/ui/widgets/chat_bubble.dart';

class DesignSystemDemoScreen extends StatelessWidget {
  const DesignSystemDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设计系统演示'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('OpenClaw', style: AppTypography.display),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '紧凑展示排版、卡片层级与聊天界面样式。',
            style: AppTypography.bodyMuted.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('排版', style: AppTypography.title),
                  const SizedBox(height: AppSpacing.sm),
                  Text('中号标题', style: AppTypography.headline),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '正文需要保持清晰、稳定，适合长时间阅读。',
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '弱化辅助文本用于次要信息或帮助说明。',
                    style: AppTypography.bodyMuted
                        .copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '说明文字用于时间戳和轻量提示。',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('聊天气泡', style: AppTypography.title),
                  const SizedBox(height: AppSpacing.md),
                  const ChatBubble(
                    message:
                        '我们已将新的网关握手流程对齐到最新事件协议。',
                    timestamp: '12:48',
                    showTail: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const ChatBubble(
                    message:
                        '很好，我会更新协议文档并提交补丁。',
                    timestamp: '12:49',
                    status: '已送达',
                    isMine: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const ChatBubble(
                    message:
                        '下次演示前我们还要验证重试逻辑。',
                    timestamp: '12:51',
                    showTail: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.ink),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('重点卡片', style: AppTypography.title),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '使用抬升卡片来强调关键信息或系统状态。',
                        style: AppTypography.bodyMuted
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
