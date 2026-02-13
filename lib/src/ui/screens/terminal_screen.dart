import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openclaw_mobile/src/rust/api/terminal.dart' as rust_terminal;
import 'package:openclaw_mobile/src/ui/theme.dart';

class TerminalScreen extends StatelessWidget {
  const TerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('混合调试终端'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '概览'),
              Tab(text: '实时终端'),
            ],
          ),
        ),
        body: Stack(
          children: [
            const _TerminalBackdrop(),
            const SafeArea(
              child: TabBarView(
                children: [
                  _OverviewTab(),
                  _LiveTerminalTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeaderBlock(),
          const SizedBox(height: AppSpacing.lg),
          const _AutoDiagnosticSection(),
          const SizedBox(height: AppSpacing.xl),
          const _LogStreamSection(),
          const SizedBox(height: AppSpacing.xl),
          const _QuickCommandsSection(),
        ],
      ),
    );
  }
}

class _LiveTerminalTab extends StatefulWidget {
  const _LiveTerminalTab();

  @override
  State<_LiveTerminalTab> createState() => _LiveTerminalTabState();
}

class _LiveTerminalTabState extends State<_LiveTerminalTab>
    with AutomaticKeepAliveClientMixin {
  late final TerminalCommandBridge _bridge;
  late final StreamSubscription<TerminalOutputChunk> _outputSubscription;
  final List<TerminalOutputLine> _lines = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final List<String> _history = [];
  int _historyIndex = -1;
  bool _sudoMode = false;
  bool _isExecuting = false;

  final List<String> _snippets = const [
    'ls',
    'ls -la',
    'pwd',
    'whoami',
    'ps aux',
    'df -h',
    'du -sh *',
    'uname -a',
    'ip a',
    'cat /proc/cpuinfo',
  ];

  @override
  void initState() {
    super.initState();
    _bridge = TerminalCommandBridge.rustOrFallback();
    _outputSubscription = _bridge.output.listen(_handleOutput);
    _pushSystemLine('实时终端已连接，可执行命令。');
  }

  @override
  void dispose() {
    _outputSubscription.cancel();
    _bridge.dispose();
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _handleOutput(TerminalOutputChunk chunk) {
    final segments = chunk.text.split('\n');
    for (final segment in segments) {
      if (segment.isEmpty) {
        continue;
      }
      _lines.add(
        TerminalOutputLine(
          text: segment,
          kind: chunk.kind,
          timestamp: chunk.timestamp,
        ),
      );
    }
    _scrollToBottom();
    if (mounted) {
      setState(() {});
    }
  }

  void _pushSystemLine(String message) {
    _lines.add(
      TerminalOutputLine(
        text: message,
        kind: TerminalLineKind.system,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _applySnippet(String snippet) {
    final text = _inputController.text;
    if (text.isEmpty) {
      _inputController.text = snippet;
    } else {
      _inputController.text = '$text $snippet';
    }
    _inputController.selection = TextSelection.collapsed(
      offset: _inputController.text.length,
    );
    _inputFocus.requestFocus();
  }

  void _cycleHistory(int offset) {
    if (_history.isEmpty) {
      return;
    }
    if (_historyIndex == -1) {
      _historyIndex = _history.length;
    }
    _historyIndex = (_historyIndex + offset).clamp(0, _history.length);
    if (_historyIndex >= 0 && _historyIndex < _history.length) {
      _inputController.text = _history[_historyIndex];
      _inputController.selection = TextSelection.collapsed(
        offset: _inputController.text.length,
      );
    } else if (_historyIndex == _history.length) {
      _inputController.clear();
    }
  }

  Future<void> _sendCommand() async {
    final rawCommand = _inputController.text.trim();
    if (rawCommand.isEmpty || _isExecuting) {
      return;
    }

    final command = _sudoMode && !rawCommand.startsWith('sudo ')
        ? 'sudo $rawCommand'
        : rawCommand;

    _lines.add(
      TerminalOutputLine(
        text: '${_sudoMode ? '#' : '\$'} $command',
        kind: TerminalLineKind.input,
        timestamp: DateTime.now(),
      ),
    );

    _history.add(rawCommand);
    _historyIndex = _history.length;
    _inputController.clear();
    _inputFocus.requestFocus();
    _scrollToBottom();

    setState(() {
      _isExecuting = true;
    });

    try {
      await _bridge.sendCommand(command, sudo: _sudoMode);
    } finally {
      if (mounted) {
        setState(() {
          _isExecuting = false;
        });
      }
    }
  }

  void _clearOutput() {
    setState(() {
      _lines.clear();
    });
    _pushSystemLine('终端输出已清空。');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TerminalHeader(
            sudoMode: _sudoMode,
            isExecuting: _isExecuting,
            onSudoChanged: (value) {
              setState(() {
                _sudoMode = value;
              });
              _pushSystemLine(
                value ? '已启用 sudo 模式。' : '已关闭 sudo 模式。',
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _TerminalOutputPanel(
            lines: _lines,
            scrollController: _scrollController,
            sudoMode: _sudoMode,
          ),
          const SizedBox(height: AppSpacing.lg),
          _CommandComposer(
            controller: _inputController,
            focusNode: _inputFocus,
            snippets: _snippets,
            sudoMode: _sudoMode,
            onSubmit: _sendCommand,
            onSnippetTap: _applySnippet,
            onHistoryBack: () => _cycleHistory(-1),
            onHistoryForward: () => _cycleHistory(1),
            onClear: _clearOutput,
            isExecuting: _isExecuting,
          ),
        ],
      ),
    );
  }
}

class _TerminalHeader extends StatelessWidget {
  const _TerminalHeader({
    required this.sudoMode,
    required this.isExecuting,
    required this.onSudoChanged,
  });

  final bool sudoMode;
  final bool isExecuting;
  final ValueChanged<bool> onSudoChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('实时终端', style: AppTypography.headline),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '支持 ANSI 输出、命令历史、快捷片段和流式 Shell。',
                style: AppTypography.bodyMuted
                    .copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  _StatusPill(
                    label: isExecuting ? '执行中' : '就绪',
                    color: isExecuting ? AppColors.warning : AppColors.success,
                  ),
                  _StatusPill(
                    label: sudoMode ? 'Sudo 已启用' : '标准用户',
                    color: sudoMode ? AppColors.danger : AppColors.brandGlow,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Sudo 模式', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.xs),
            Switch.adaptive(
              value: sudoMode,
              activeColor: AppColors.danger,
              onChanged: onSudoChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }
}

class _TerminalOutputPanel extends StatelessWidget {
  const _TerminalOutputPanel({
    required this.lines,
    required this.scrollController,
    required this.sudoMode,
  });

  final List<TerminalOutputLine> lines;
  final ScrollController scrollController;
  final bool sudoMode;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text('终端输出', style: AppTypography.title),
                  const SizedBox(width: AppSpacing.sm),
                  if (sudoMode)
                    _StatusPill(label: '提权', color: AppColors.danger),
                  const Spacer(),
                  Text(
                    '${lines.length} 行',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: lines.length,
                  itemBuilder: (context, index) {
                    return _TerminalLineRow(line: lines[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalLineRow extends StatelessWidget {
  const _TerminalLineRow({required this.line});

  final TerminalOutputLine line;

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.ibmPlexMono(
      fontSize: 13,
      height: 1.4,
      color: AppColors.textPrimary,
    );
    final lineStyle = switch (line.kind) {
      TerminalLineKind.input => baseStyle.copyWith(
          color: AppColors.brandGlow,
          fontWeight: FontWeight.w600,
        ),
      TerminalLineKind.system => baseStyle.copyWith(color: AppColors.accent),
      TerminalLineKind.error => baseStyle.copyWith(color: AppColors.danger),
      _ => baseStyle,
    };
    final spans = line.kind == TerminalLineKind.output
        ? AnsiParser.parse(line.text, lineStyle)
        : [TextSpan(text: line.text, style: lineStyle)];
    final timeStyle = GoogleFonts.ibmPlexMono(
      fontSize: 11,
      height: 1.4,
      color: AppColors.textFaint,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(_formatTime(line.timestamp), style: timeStyle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SelectableText.rich(
              TextSpan(children: spans),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandComposer extends StatelessWidget {
  const _CommandComposer({
    required this.controller,
    required this.focusNode,
    required this.snippets,
    required this.sudoMode,
    required this.onSubmit,
    required this.onSnippetTap,
    required this.onHistoryBack,
    required this.onHistoryForward,
    required this.onClear,
    required this.isExecuting,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> snippets;
  final bool sudoMode;
  final VoidCallback onSubmit;
  final ValueChanged<String> onSnippetTap;
  final VoidCallback onHistoryBack;
  final VoidCallback onHistoryForward;
  final VoidCallback onClear;
  final bool isExecuting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('智能命令输入', style: AppTypography.title),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: snippets.map((snippet) {
            return ActionChip(
              label: Text(snippet),
              onPressed: () => onSnippetTap(snippet),
              backgroundColor: AppColors.surfaceRaised,
              labelStyle:
                  AppTypography.caption.copyWith(color: AppColors.textMuted),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: const BorderSide(color: AppColors.borderSubtle),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: sudoMode
                          ? AppColors.danger.withValues(alpha: 0.16)
                          : AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sudoMode
                            ? AppColors.danger.withValues(alpha: 0.45)
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: Text(
                      sudoMode ? '#' : '\$',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color:
                            sudoMode ? AppColors.danger : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSubmit(),
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: sudoMode
                            ? '请输入提权命令...'
                            : '输入命令或点击快捷片段...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        fillColor: AppColors.surfaceRaised,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up),
                        color: AppColors.textMuted,
                        onPressed: onHistoryBack,
                        tooltip: '上一条历史',
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        color: AppColors.textMuted,
                        onPressed: onHistoryForward,
                        tooltip: '下一条历史',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '点击片段可快速插入，使用箭头浏览历史。',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textFaint),
                    ),
                  ),
                  TextButton(
                    onPressed: onClear,
                    child: const Text('清空'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton.icon(
                    onPressed: isExecuting ? null : onSubmit,
                    icon: const Icon(Icons.send),
                    label: Text(isExecuting ? '运行中' : '运行'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TerminalCommandBridge {
  TerminalCommandBridge._(
    this._controller, {
    required this.gatewayUrl,
    this.sessionKey,
  });

  static const _defaultGatewayUrl = 'ws://127.0.0.1:18789';

  factory TerminalCommandBridge.rustOrFallback({
    String gatewayUrl = _defaultGatewayUrl,
    String? sessionKey,
  }) {
    return TerminalCommandBridge._(
      StreamController<TerminalOutputChunk>.broadcast(),
      gatewayUrl: gatewayUrl,
      sessionKey: sessionKey,
    );
  }

  final StreamController<TerminalOutputChunk> _controller;
  final String gatewayUrl;
  final String? sessionKey;

  Stream<TerminalOutputChunk> get output => _controller.stream;

  Future<void> sendCommand(String command, {bool sudo = false}) async {
    try {
      await for (final chunk in rust_terminal.execCommand(
        url: gatewayUrl,
        command: command,
        sessionKey: sessionKey,
      )) {
        _controller.add(
          TerminalOutputChunk(
            text: chunk.text,
            kind: _mapKind(chunk.kind),
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (error) {
      _controller.add(
        TerminalOutputChunk(
          text: error.toString(),
          kind: TerminalLineKind.error,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  TerminalLineKind _mapKind(String kind) {
    return switch (kind) {
      'error' => TerminalLineKind.error,
      'system' => TerminalLineKind.system,
      _ => TerminalLineKind.output,
    };
  }

  void dispose() {
    _controller.close();
  }
}

class TerminalOutputChunk {
  TerminalOutputChunk({
    required this.text,
    required this.kind,
    required this.timestamp,
  });

  final String text;
  final TerminalLineKind kind;
  final DateTime timestamp;
}

class TerminalOutputLine {
  TerminalOutputLine({
    required this.text,
    required this.kind,
    required this.timestamp,
  });

  final String text;
  final TerminalLineKind kind;
  final DateTime timestamp;
}

enum TerminalLineKind {
  input,
  output,
  system,
  error,
}

class AnsiParser {
  static final RegExp _ansiRegex = RegExp(r'\x1B\[[0-9;]*m');

  static List<InlineSpan> parse(String input, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    var currentStyle = baseStyle;
    var index = 0;

    for (final match in _ansiRegex.allMatches(input)) {
      if (match.start > index) {
        spans.add(TextSpan(
          text: input.substring(index, match.start),
          style: currentStyle,
        ));
      }

      final code = input.substring(match.start, match.end);
      currentStyle = _applyAnsi(code, baseStyle, currentStyle);
      index = match.end;
    }

    if (index < input.length) {
      spans.add(TextSpan(text: input.substring(index), style: currentStyle));
    }

    return spans;
  }

  static TextStyle _applyAnsi(
    String sequence,
    TextStyle baseStyle,
    TextStyle currentStyle,
  ) {
    final codes = sequence
        .replaceAll('\x1B[', '')
        .replaceAll('m', '')
        .split(';')
        .where((code) => code.isNotEmpty)
        .map(int.tryParse)
        .whereType<int>()
        .toList();

    if (codes.isEmpty) {
      return baseStyle;
    }

    var style = currentStyle;
    for (final code in codes) {
      switch (code) {
        case 0:
          style = baseStyle;
          break;
        case 1:
          style = style.copyWith(fontWeight: FontWeight.w700);
          break;
        case 22:
          style = style.copyWith(fontWeight: FontWeight.w500);
          break;
        case 39:
          style = style.copyWith(color: baseStyle.color);
          break;
        default:
          final color = _ansiColor(code);
          if (color != null) {
            style = style.copyWith(color: color);
          }
      }
    }

    return style;
  }

  static Color? _ansiColor(int code) {
    return switch (code) {
      30 => const Color(0xFF1B1F24),
      31 => AppColors.danger,
      32 => AppColors.success,
      33 => AppColors.warning,
      34 => AppColors.brandGlow,
      35 => const Color(0xFFB28BFF),
      36 => AppColors.accent,
      37 => AppColors.textPrimary,
      90 => AppColors.textFaint,
      91 => const Color(0xFFFF8296),
      92 => const Color(0xFF7EF2B3),
      93 => const Color(0xFFF7D67E),
      94 => const Color(0xFF8FB5FF),
      95 => const Color(0xFFCCA4FF),
      96 => const Color(0xFF7FF0E1),
      97 => const Color(0xFFEFF3FF),
      _ => null,
    };
  }
}

String _formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final second = time.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

class _TerminalBackdrop extends StatelessWidget {
  const _TerminalBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0D13),
            Color(0xFF0F1622),
            Color(0xFF151C29),
          ],
        ),
      ),
      child: Stack(
        children: const [
          _GlowOrb(
            alignment: Alignment(-0.9, -0.8),
            color: Color(0x334EE1C1),
            size: 220,
          ),
          _GlowOrb(
            alignment: Alignment(0.8, -0.6),
            color: Color(0x337F9CFF),
            size: 260,
          ),
          _GlowOrb(
            alignment: Alignment(0.2, 0.9),
            color: Color(0x22F5B548),
            size: 240,
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.alignment,
    required this.color,
    required this.size,
  });

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 120,
              spreadRadius: 40,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('现代深色控制台', style: AppTypography.display),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '面向快速恢复的混合诊断界面：实时信号、筛选日志与一键修复。',
          style: AppTypography.bodyMuted.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '流式运行',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '上次同步：00:12 前',
              style: AppTypography.caption.copyWith(color: AppColors.textFaint),
            ),
          ],
        ),
      ],
    );
  }
}

class _AutoDiagnosticSection extends StatelessWidget {
  const _AutoDiagnosticSection();

  @override
  Widget build(BuildContext context) {
    final diagnostics = [
      const _DiagnosticStatus(
        title: '网关',
        status: '在线',
        detail: '延迟稳定在 23ms',
        color: AppColors.success,
        icon: Icons.hub_outlined,
      ),
      const _DiagnosticStatus(
        title: 'NAS',
        status: '降级',
        detail: '卷 3 重新挂载已排队',
        color: AppColors.warning,
        icon: Icons.storage_outlined,
      ),
      const _DiagnosticStatus(
        title: '模型',
        status: '空闲',
        detail: '当前无推理任务',
        color: AppColors.brandGlow,
        icon: Icons.memory_outlined,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('自动诊断', style: AppTypography.title),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 720;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: diagnostics.map((status) {
                final width = isWide
                    ? (constraints.maxWidth - AppSpacing.md * 2) / 3
                    : constraints.maxWidth;
                return SizedBox(
                  width: width,
                  child: _DiagnosticCard(status: status),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _DiagnosticStatus {
  const _DiagnosticStatus({
    required this.title,
    required this.status,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String title;
  final String status;
  final String detail;
  final Color color;
  final IconData icon;
}

class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({required this.status});

  final _DiagnosticStatus status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: status.color.withValues(alpha: 0.35)),
                  ),
                  child: Icon(status.icon, color: status.color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(status.title, style: AppTypography.bodyMuted),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        status.status,
                        style:
                            AppTypography.title.copyWith(color: status.color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              status.detail,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogStreamSection extends StatelessWidget {
  const _LogStreamSection();

  @override
  Widget build(BuildContext context) {
    final logs = [
      const _LogEntry(
        time: '22:41:11',
        source: '网关',
        message: '握手周期完成，实时事件已恢复。',
        level: LogLevel.info,
      ),
      const _LogEntry(
        time: '22:41:08',
        source: 'NAS',
        message: '挂载检查发现卷 3 响应偏慢。',
        level: LogLevel.warn,
      ),
      const _LogEntry(
        time: '22:41:02',
        source: '模型执行器',
        message: '严重：推理队列阻塞（重试 2/3）。',
        level: LogLevel.critical,
      ),
      const _LogEntry(
        time: '22:40:57',
        source: '网关',
        message: '错误：令牌刷新失败，正在使用备用密钥重试。',
        level: LogLevel.error,
      ),
      const _LogEntry(
        time: '22:40:49',
        source: '监控器',
        message: '自愈任务已计划在 22:45:00 执行。',
        level: LogLevel.info,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('智能日志流', style: AppTypography.title),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                '已筛选：错误 + 严重',
                style:
                    AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              const _LogStreamHeader(),
              const Divider(height: 1),
              SizedBox(
                height: 260,
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemBuilder: (context, index) {
                    return _LogRow(entry: logs[index]);
                  },
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemCount: logs.length,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogStreamHeader extends StatelessWidget {
  const _LogStreamHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text('时间戳', style: AppTypography.caption),
          ),
          Expanded(
            flex: 2,
            child: Text('来源', style: AppTypography.caption),
          ),
          Expanded(
            flex: 4,
            child: Text('消息', style: AppTypography.caption),
          ),
        ],
      ),
    );
  }
}

enum LogLevel {
  info,
  warn,
  error,
  critical,
}

class _LogEntry {
  const _LogEntry({
    required this.time,
    required this.source,
    required this.message,
    required this.level,
  });

  final String time;
  final String source;
  final String message;
  final LogLevel level;
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final _LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final levelColor = switch (entry.level) {
      LogLevel.info => AppColors.textMuted,
      LogLevel.warn => AppColors.warning,
      LogLevel.error => AppColors.danger,
      LogLevel.critical => AppColors.accent,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: entry.level == LogLevel.info
            ? AppColors.surfaceRaised
            : levelColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.level == LogLevel.info
              ? AppColors.borderSubtle
              : levelColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(entry.time, style: AppTypography.caption),
          ),
          Expanded(
            flex: 2,
            child: Text(
              entry.source,
              style: AppTypography.bodyMuted.copyWith(color: levelColor),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              entry.message,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCommandsSection extends StatelessWidget {
  const _QuickCommandsSection();

  @override
  Widget build(BuildContext context) {
    final commands = [
      const _QuickCommand(
        label: '重启网关',
        detail: '重新建立 websocket 并加载事件',
        icon: Icons.restart_alt_outlined,
        color: AppColors.brandGlow,
      ),
      const _QuickCommand(
        label: '清理缓存',
        detail: '清除本地临时数据与过期令牌',
        icon: Icons.cleaning_services_outlined,
        color: AppColors.warning,
      ),
      const _QuickCommand(
        label: '重新挂载 NAS',
        detail: '强制重连卷 3',
        icon: Icons.storage_outlined,
        color: AppColors.accent,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('快捷命令', style: AppTypography.title),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: commands.map((command) {
            return _QuickCommandCard(command: command);
          }).toList(),
        ),
      ],
    );
  }
}

class _QuickCommand {
  const _QuickCommand({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String detail;
  final IconData icon;
  final Color color;
}

class _QuickCommandCard extends StatelessWidget {
  const _QuickCommandCard({required this.command});

  final _QuickCommand command;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: command.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: command.color.withValues(alpha: 0.35)),
                    ),
                    child: Icon(command.icon, color: command.color),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      command.label,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                command.detail,
                style: AppTypography.bodyMuted
                    .copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: command.color,
                    foregroundColor: AppColors.ink,
                  ),
                  child: const Text('执行'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
