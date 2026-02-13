import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openclaw_mobile/src/rust/api/events.dart';
import 'package:openclaw_mobile/src/rust/api/connection.dart';
import 'package:openclaw_mobile/src/rust/api/simple.dart';
import 'package:openclaw_mobile/src/rust/frb_generated.dart';
import 'package:openclaw_mobile/src/services/gateway_service.dart';
import 'package:openclaw_mobile/src/ui/screens/design_system_demo.dart';
import 'package:openclaw_mobile/src/ui/screens/terminal_screen.dart';
import 'package:openclaw_mobile/src/ui/theme.dart';
import 'package:openclaw_mobile/src/ui/widgets/canvas_view.dart';
import 'package:openclaw_mobile/src/ui/widgets/chat_bubble.dart';

final gatewayServiceProvider = Provider<GatewayService>((ref) {
  throw UnimplementedError('必须在 ProviderScope 中提供 GatewayService。');
});

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(ref.read(gatewayServiceProvider));
});

Future<void> bootstrap(
    {GatewayService? gatewayService, RustLibApi? rustApi}) async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;

  if (rustApi != null) {
    RustLib.initMock(api: rustApi);
  } else {
    try {
      await RustLib.init().timeout(const Duration(seconds: 20));
    } on TimeoutException catch (error) {
      startupError = error;
      debugPrint('RustLib.init timed out: $error');
    } catch (error) {
      startupError = error;
      debugPrint('RustLib.init failed: $error');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        gatewayServiceProvider.overrideWithValue(
          gatewayService ?? const RustGatewayService(),
        ),
      ],
      child: MyApp(startupError: startupError),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.startupError});

  final Object? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      routes: {
        '/design-demo': (context) => const DesignSystemDemoScreen(),
        '/terminal': (context) => const TerminalScreen(),
      },
      home: startupError == null
          ? const ChatScreen()
          : StartupErrorScreen(error: startupError!),
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '启动失败：$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

const String kDefaultSessionId = '主会话';
const String kAgentSessionPrefix = '会话-';

class ChatMessage {
  const ChatMessage({
    required this.message,
    required this.timestamp,
    this.isMine = false,
    this.status,
  });

  final String message;
  final String timestamp;
  final bool isMine;
  final String? status;
}

class ChatSession {
  const ChatSession({
    required this.messages,
    required this.statusText,
    required this.isConnecting,
    required this.isConnected,
    this.canvasScene,
  });

  final List<ChatMessage> messages;
  final String statusText;
  final bool isConnecting;
  final bool isConnected;
  final CanvasScene? canvasScene;

  factory ChatSession.initial() {
    return const ChatSession(
      messages: [],
      statusText: '空闲',
      isConnecting: false,
      isConnected: false,
      canvasScene: null,
    );
  }

  ChatSession copyWith({
    List<ChatMessage>? messages,
    String? statusText,
    bool? isConnecting,
    bool? isConnected,
    CanvasScene? canvasScene,
  }) {
    return ChatSession(
      messages: messages ?? this.messages,
      statusText: statusText ?? this.statusText,
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      canvasScene: canvasScene ?? this.canvasScene,
    );
  }
}

class ChatState {
  const ChatState({
    required this.sessions,
    required this.archivedSessions,
    required this.activeSessionId,
  });

  final Map<String, ChatSession> sessions;
  final Map<String, ChatSession> archivedSessions;
  final String activeSessionId;

  factory ChatState.initial() {
    return ChatState(
      sessions: {
        kDefaultSessionId: ChatSession.initial(),
      },
      archivedSessions: const {},
      activeSessionId: kDefaultSessionId,
    );
  }

  ChatSession? get activeSession => sessions[activeSessionId];

  ChatState copyWith({
    Map<String, ChatSession>? sessions,
    Map<String, ChatSession>? archivedSessions,
    String? activeSessionId,
  }) {
    return ChatState(
      sessions: sessions ?? this.sessions,
      archivedSessions: archivedSessions ?? this.archivedSessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._gatewayService) : super(ChatState.initial());

  final GatewayService _gatewayService;
  StreamSubscription<GatewayEvent>? _gatewaySubscription;

  void switchSession(String sessionId) {
    if (!state.sessions.containsKey(sessionId)) {
      return;
    }
    state = state.copyWith(activeSessionId: sessionId);
  }

  void startNewSession() {
    final newSessionId = _nextSessionId();
    final sessions = Map<String, ChatSession>.from(state.sessions)
      ..[newSessionId] = ChatSession.initial();
    state = state.copyWith(
      sessions: sessions,
      activeSessionId: newSessionId,
    );
    _addSystemMessage(newSessionId, '会话已开始。', status: '会话');
  }

  Future<void> endSession({String? sessionId}) async {
    final targetId = sessionId ?? state.activeSessionId;
    final existing = state.sessions[targetId];
    if (existing == null) {
      return;
    }

    if (existing.isConnected || existing.isConnecting) {
      await disconnect(sessionId: targetId);
    }

    _addSystemMessage(targetId, '会话已归档。', status: '会话');

    final session = state.sessions[targetId];
    if (session == null) {
      return;
    }

    final sessions = Map<String, ChatSession>.from(state.sessions)
      ..remove(targetId);
    final archived = Map<String, ChatSession>.from(state.archivedSessions)
      ..[targetId] = session;

    if (sessions.isEmpty) {
      final newSessionId = _nextSessionId(usedIds: archived.keys.toSet());
      sessions[newSessionId] = ChatSession.initial();
      state = state.copyWith(
        sessions: sessions,
        archivedSessions: archived,
        activeSessionId: newSessionId,
      );
      _addSystemMessage(newSessionId, '会话已开始。', status: '会话');
      return;
    }

    final nextActive = sessions.containsKey(state.activeSessionId)
        ? state.activeSessionId
        : sessions.keys.first;
    state = state.copyWith(
      sessions: sessions,
      archivedSessions: archived,
      activeSessionId: nextActive,
    );
  }

  Future<void> connect(String url) async {
    final sessionId = state.activeSessionId;
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _setStatus(
        sessionId,
        '网关地址不能为空。',
        isConnecting: false,
        isConnected: false,
      );
      _addSystemMessage(sessionId, '网关地址不能为空。', status: '错误');
      return;
    }

    await _gatewaySubscription?.cancel();
    _setStatus(
      sessionId,
      '正在连接到 $trimmed...',
      isConnecting: true,
      isConnected: false,
    );
    _addSystemMessage(sessionId, '正在连接到 $trimmed...', status: '网关');

    try {
      final stream = _gatewayService.connect(url: trimmed);
      _gatewaySubscription = stream.listen(
        (event) {
          final eventText = event.toString();

          if (eventText.startsWith('GatewayEvent.connected')) {
            _setStatus(sessionId, '已连接',
                isConnecting: false, isConnected: true);
            _addSystemMessage(sessionId, '网关已连接。', status: '已连接');
          } else if (eventText.startsWith('GatewayEvent.disconnected')) {
            final reason = _extractEventField(eventText) ?? '未知原因';
            _setStatus(
              sessionId,
              '已断开：$reason',
              isConnecting: false,
              isConnected: false,
            );
            _addSystemMessage(
              sessionId,
              '网关已断开：$reason',
              status: '已断开',
            );
          } else if (eventText.startsWith('GatewayEvent.message')) {
            final message = _extractEventField(eventText) ?? eventText;
            final canvasScene = CanvasScene.tryParse(message);
            if (canvasScene != null) {
              _updateSession(
                sessionId,
                (session) => session.copyWith(canvasScene: canvasScene),
              );
            } else {
              _addMessage(
                sessionId,
                ChatMessage(
                  message: message,
                  timestamp: _timestamp(),
                  status: '网关',
                ),
              );
            }
          } else if (eventText.startsWith('GatewayEvent.error')) {
            final errorMessage =
                _extractEventField(eventText) ?? '未知错误';
            _setStatus(
              sessionId,
              '错误：$errorMessage',
              isConnecting: false,
              isConnected: false,
            );
            _addSystemMessage(
              sessionId,
              '网关错误：$errorMessage',
              status: '错误',
            );
          } else {
            _addSystemMessage(sessionId, eventText, status: '网关');
          }
        },
        onError: (error) {
          _setStatus(
            sessionId,
            '流错误：$error',
            isConnecting: false,
            isConnected: false,
          );
          _addSystemMessage(sessionId, '流错误：$error', status: '错误');
        },
        onDone: () {
          _setStatus(sessionId, '已断开',
              isConnecting: false, isConnected: false);
          _addSystemMessage(sessionId, '连接流已关闭。', status: '已断开');
        },
      );
    } catch (e) {
      _setStatus(sessionId, '异常：$e',
          isConnecting: false, isConnected: false);
      _addSystemMessage(sessionId, '异常：$e', status: '错误');
    }
  }

  Future<void> disconnect({String? sessionId}) async {
    final targetId = sessionId ?? state.activeSessionId;
    await _gatewaySubscription?.cancel();
    _gatewaySubscription = null;
    _setStatus(targetId, '已断开',
        isConnecting: false, isConnected: false);
    _addSystemMessage(
      targetId,
      '已断开（客户端请求）。',
      status: '已断开',
    );
  }

  Future<void> sendGreeting(String name) async {
    final trimmed = name.trim();
    final label = trimmed.isEmpty ? 'OpenClaw 操作员' : trimmed;
    _addMessage(
      state.activeSessionId,
      ChatMessage(
        message: '$label 发送了问候。',
        timestamp: _timestamp(),
        isMine: true,
        status: _deliveryStatus(),
      ),
    );

    await _sendAgentTurnRequest(trimmed.isEmpty ? label : trimmed);

    final greeting = await greet(name: label);
    _addMessage(
      state.activeSessionId,
      ChatMessage(
        message: greeting,
        timestamp: _timestamp(),
        status: 'Rust 引擎',
      ),
    );
  }

  void sendMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _addMessage(
      state.activeSessionId,
      ChatMessage(
        message: trimmed,
        timestamp: _timestamp(),
        isMine: true,
        status: _deliveryStatus(),
      ),
    );

    unawaited(_sendAgentTurnRequest(trimmed));
  }

  void sendInputEvent(CanvasInputEvent event) {
    final payload = jsonEncode({
      ...event.toJson(),
      'sessionId': state.activeSessionId,
    });
    _addMessage(
      state.activeSessionId,
      ChatMessage(
        message: payload,
        timestamp: _timestamp(),
        isMine: true,
        status: '输入',
      ),
    );
  }

  Future<void> _sendAgentTurnRequest(String message) async {
    final requestId = 'req-${DateTime.now().millisecondsSinceEpoch}';
    final frameJson = await GatewayClient(url: 'gateway').agentTurnRequest(
      requestId: requestId,
      message: message,
      sessionKey: state.activeSessionId,
    );
    await _gatewayService.sendRequest(frameJson);
  }

  String? _extractEventField(String eventText) {
    final match = RegExp(r'field0: (.*)\)$').firstMatch(eventText);
    return match?.group(1);
  }

  void _setStatus(
    String sessionId,
    String statusText, {
    required bool isConnecting,
    required bool isConnected,
  }) {
    _updateSession(
      sessionId,
      (session) => session.copyWith(
        statusText: statusText,
        isConnecting: isConnecting,
        isConnected: isConnected,
      ),
    );
  }

  void _addSystemMessage(String sessionId, String message, {String? status}) {
    _addMessage(
      sessionId,
      ChatMessage(
        message: message,
        timestamp: _timestamp(),
        status: status,
      ),
    );
  }

  void _addMessage(String sessionId, ChatMessage message) {
    _updateSession(
      sessionId,
      (session) => session.copyWith(
          messages: List<ChatMessage>.from(session.messages)..add(message)),
    );
  }

  String _deliveryStatus() {
    final session = state.activeSession;
    if (session?.isConnected ?? false) {
      return '已发送';
    }
    if (session?.isConnecting ?? false) {
      return '排队中';
    }
    return '离线';
  }

  String _timestamp() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  void dispose() {
    _gatewaySubscription?.cancel();
    super.dispose();
  }

  void _updateSession(
    String sessionId,
    ChatSession Function(ChatSession session) update,
  ) {
    final sessions = Map<String, ChatSession>.from(state.sessions);
    final session = sessions[sessionId];
    if (session == null) {
      return;
    }
    sessions[sessionId] = update(session);
    state = state.copyWith(sessions: sessions);
  }

  String _nextSessionId({Set<String>? usedIds}) {
    final existing = usedIds ??
        {
          ...state.sessions.keys,
          ...state.archivedSessions.keys,
        };
    if (!existing.contains(kDefaultSessionId)) {
      return kDefaultSessionId;
    }
    var maxIndex = 0;
    for (final id in existing) {
      if (!id.startsWith(kAgentSessionPrefix)) {
        continue;
      }
      final suffix = id.substring(kAgentSessionPrefix.length);
      final parsed = int.tryParse(suffix);
      if (parsed != null && parsed > maxIndex) {
        maxIndex = parsed;
      }
    }
    return '$kAgentSessionPrefix${maxIndex + 1}';
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _defaultGatewayUrl = 'ws://127.0.0.1:18789';
  final _urlController = TextEditingController(text: _defaultGatewayUrl);
  final _nameController = TextEditingController(text: 'OpenClaw 操作员');
  final _messageController = TextEditingController();
  bool _showCanvas = false;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final chatController = ref.read(chatControllerProvider.notifier);
    final activeSession = chatState.activeSession ?? ChatSession.initial();

    return Scaffold(
      drawer: _SessionDrawer(
        state: chatState,
        controller: chatController,
      ),
      appBar: AppBar(
        title: const Text('OpenClaw 移动端'),
        actions: [
          IconButton(
            tooltip: '设计系统演示',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/design-demo'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderRow(
                sessionId: chatState.activeSessionId,
                session: activeSession,
                isCanvasVisible: _showCanvas,
                onToggleCanvas: () {
                  setState(() {
                    _showCanvas = !_showCanvas;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_showCanvas) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('A2UI 画布',
                                  style: AppTypography.title),
                            ),
                            Text(
                              activeSession.canvasScene?.isEmpty ?? true
                                  ? '空闲'
                                  : '实时',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 260,
                          child: CanvasView(
                            scene: activeSession.canvasScene,
                            backgroundColor: AppColors.canvas,
                            onInputEvent: chatController.sendInputEvent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('会话设置', style: AppTypography.title),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '操作员名称',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: '网关地址',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: activeSession.isConnecting
                                  ? null
                                  : () => chatController.connect(
                                        _urlController.text,
                                      ),
                              child: Text(
                                activeSession.isConnected
                                    ? '重新连接'
                                    : '连接',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.surfaceRaised,
                                foregroundColor: AppColors.textPrimary,
                              ),
                              onPressed: (activeSession.isConnected ||
                                      activeSession.isConnecting)
                                  ? chatController.disconnect
                                  : null,
                              child: const Text('断开连接'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => chatController.sendGreeting(
                                _nameController.text,
                              ),
                              child: const Text('通过 Rust 发送问候'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceRaised,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.borderSubtle,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                activeSession.statusText,
                                style: AppTypography.bodyMuted.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: chatController.startNewSession,
                              icon: const Icon(Icons.add),
                              label: const Text('开始新会话'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.surfaceRaised,
                                foregroundColor: AppColors.textPrimary,
                              ),
                              onPressed: () => chatController.endSession(),
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text('结束会话'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('消息流',
                                  style: AppTypography.title),
                            ),
                            _StatusPill(session: activeSession),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: activeSession.messages.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无消息。请先开始会话或发送问候。',
                                  style: AppTypography.bodyMuted.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                itemCount: activeSession.messages.length,
                                itemBuilder: (context, index) {
                                  final message = activeSession.messages[index];
                                  final showTail = _shouldShowTail(
                                    activeSession.messages,
                                    index,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: ChatBubble(
                                      message: message.message,
                                      timestamp: message.timestamp,
                                      isMine: message.isMine,
                                      status: message.status,
                                      showTail: showTail,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderSubtle, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: '发送消息...',
                        ),
                        onSubmitted: (value) {
                          chatController.sendMessage(value);
                          _messageController.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: () {
                        chatController.sendMessage(_messageController.text);
                        _messageController.clear();
                      },
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionDrawer extends StatelessWidget {
  const _SessionDrawer({
    required this.state,
    required this.controller,
  });

  final ChatState state;
  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    final sessionTiles = state.sessions.entries.map((entry) {
      final isActive = entry.key == state.activeSessionId;
      return ListTile(
        leading: const Icon(Icons.forum_outlined),
        title: Text(entry.key),
        subtitle: Text(entry.value.statusText),
        selected: isActive,
        onTap: () {
          controller.switchSession(entry.key);
          Navigator.of(context).pop();
        },
      );
    }).toList();

    final archivedTiles = state.archivedSessions.entries.map((entry) {
      return ListTile(
        leading: const Icon(Icons.archive_outlined),
        title: Text(entry.key),
        subtitle: const Text('已归档'),
        enabled: false,
      );
    }).toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('工具', style: AppTypography.title),
            ),
            ListTile(
              leading: const Icon(Icons.terminal_outlined),
              title: const Text('混合调试终端'),
              subtitle: const Text('诊断、日志、快速恢复'),
              onTap: () {
                Navigator.of(context).pushNamed('/terminal');
                Navigator.of(context).pop();
              },
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('会话', style: AppTypography.title),
            ),
            Expanded(
              child: ListView(
                children: [
                  ...sessionTiles,
                  if (archivedTiles.isNotEmpty) const Divider(height: 1),
                  if (archivedTiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text('已归档', style: AppTypography.bodyMuted),
                    ),
                  ...archivedTiles,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sessionId,
    required this.session,
    required this.isCanvasVisible,
    required this.onToggleCanvas,
  });

  final String sessionId;
  final ChatSession session;
  final bool isCanvasVisible;
  final VoidCallback onToggleCanvas;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('任务控制中心', style: AppTypography.headline),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '通过新的聊天界面监控网关事件并发送快速命令。',
                style: AppTypography.bodyMuted
                    .copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '当前会话：$sessionId',
                style:
                    AppTypography.body.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StatusPill(session: session),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onToggleCanvas,
              icon: Icon(
                isCanvasVisible
                    ? Icons.visibility_off_outlined
                    : Icons.dashboard_customize_outlined,
              ),
              label: Text(isCanvasVisible ? '隐藏画布' : '切换画布'),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.session});

  final ChatSession session;

  @override
  Widget build(BuildContext context) {
    final color = session.isConnected
        ? AppColors.success
        : session.isConnecting
            ? AppColors.warning
            : AppColors.textFaint;
    final label = session.isConnected
        ? '已连接'
        : session.isConnecting
            ? '连接中...'
            : '离线';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }
}

bool _shouldShowTail(List<ChatMessage> messages, int index) {
  if (index == messages.length - 1) {
    return true;
  }
  return messages[index + 1].isMine != messages[index].isMine;
}
