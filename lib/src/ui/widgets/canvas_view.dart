import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class CanvasScene {
  const CanvasScene({required this.commands, this.logicalSize});

  final List<CanvasCommand> commands;
  final Size? logicalSize;

  bool get isEmpty => commands.isEmpty;

  static const CanvasScene empty = CanvasScene(commands: []);

  static CanvasScene? tryParse(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    dynamic payload;
    try {
      payload = jsonDecode(trimmed);
    } catch (_) {
      return _parseFromText(trimmed);
    }

    if (payload is Map<String, dynamic>) {
      return _parseFromMap(payload);
    }
    if (payload is List) {
      return _parseFromList(payload, null);
    }
    return null;
  }

  static CanvasScene? _parseFromMap(Map<String, dynamic> map) {
    final canvasMap = _extractCanvasMap(map);
    final commandsValue =
        canvasMap['commands'] ?? canvasMap['ops'] ?? canvasMap['draw'];
    if (commandsValue == null) {
      return null;
    }

    final sceneSize = _parseSceneSize(canvasMap) ?? _parseSceneSize(map);
    final commands = _parseCommands(commandsValue);
    if (commands.isEmpty) {
      return null;
    }

    return CanvasScene(commands: commands, logicalSize: sceneSize);
  }

  static Map<String, dynamic> _extractCanvasMap(Map<String, dynamic> map) {
    final type = map['type'] ?? map['event'] ?? map['kind'];
    if (type is String && _looksLikeCanvasType(type)) {
      return map;
    }
    final canvas = map['canvas'];
    if (canvas is Map<String, dynamic>) {
      return canvas;
    }
    final payload = map['payload'];
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    return map;
  }

  static bool _looksLikeCanvasType(String type) {
    final normalized = type.toLowerCase();
    return normalized.contains('canvas') || normalized.contains('a2ui');
  }

  static CanvasScene? _parseFromList(List<dynamic> list, Size? size) {
    final commands = _parseCommands(list);
    if (commands.isEmpty) {
      return null;
    }
    return CanvasScene(commands: commands, logicalSize: size);
  }

  static CanvasScene? _parseFromText(String text) {
    final lines = text
        .split(RegExp(r'[\n;]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return null;
    }

    final commands = <CanvasCommand>[];
    for (final line in lines) {
      final command = _parseCommandString(line);
      if (command != null) {
        commands.add(command);
      }
    }
    if (commands.isEmpty) {
      return null;
    }
    return CanvasScene(commands: commands);
  }

  static List<CanvasCommand> _parseCommands(dynamic value) {
    if (value is List) {
      return value
          .map(_parseCommand)
          .whereType<CanvasCommand>()
          .toList(growable: false);
    }
    if (value is String) {
      final parsed = _parseFromText(value);
      return parsed?.commands ?? const [];
    }
    return const [];
  }

  static CanvasCommand? _parseCommand(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _parseCommandMap(value);
    }
    if (value is String) {
      return _parseCommandString(value);
    }
    return null;
  }

  static CanvasCommand? _parseCommandMap(Map<String, dynamic> map) {
    final typeRaw = map['type'] ?? map['cmd'] ?? map['op'];
    if (typeRaw is! String) {
      return null;
    }
    final type = typeRaw.toLowerCase();
    switch (type) {
      case 'line':
        final start = _parseOffset(map, 'x1', 'y1') ?? _parsePair(map['from']);
        final end = _parseOffset(map, 'x2', 'y2') ?? _parsePair(map['to']);
        if (start == null || end == null) {
          return null;
        }
        return CanvasCommand.line(
          start: start,
          end: end,
          color: _parseColor(map['color'] ?? map['stroke']) ?? Colors.white,
          strokeWidth:
              _parseDouble(map['strokeWidth'] ?? map['width'], 1.0) ?? 1.0,
        );
      case 'box':
      case 'rect':
      case 'rectangle':
        final rect = _parseRect(map) ?? _parseRect(map['rect']);
        if (rect == null) {
          return null;
        }
        return CanvasCommand.box(
          rect: rect,
          strokeColor:
              _parseColor(map['color'] ?? map['stroke']) ?? Colors.white,
          fillColor: _parseColor(map['fill'] ?? map['fillColor']),
          strokeWidth:
              _parseDouble(map['strokeWidth'] ?? map['width'], 1.0) ?? 1.0,
        );
      case 'text':
        final position = _parseOffset(map, 'x', 'y') ?? _parsePair(map['pos']);
        final text = map['text']?.toString() ?? map['value']?.toString();
        if (position == null || text == null) {
          return null;
        }
        return CanvasCommand.text(
          position: position,
          text: text,
          color: _parseColor(map['color']) ?? Colors.white,
          fontSize: _parseDouble(map['fontSize'] ?? map['size'], 14.0) ?? 14.0,
        );
      default:
        return null;
    }
  }

  static CanvasCommand? _parseCommandString(String line) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return null;
    }
    final command = parts.first.toLowerCase();
    switch (command) {
      case 'line':
        if (parts.length < 5) {
          return null;
        }
        final x1 = double.tryParse(parts[1]);
        final y1 = double.tryParse(parts[2]);
        final x2 = double.tryParse(parts[3]);
        final y2 = double.tryParse(parts[4]);
        if (x1 == null || y1 == null || x2 == null || y2 == null) {
          return null;
        }
        final color = parts.length > 5 ? _parseColor(parts[5]) : null;
        final width = parts.length > 6 ? double.tryParse(parts[6]) : null;
        return CanvasCommand.line(
          start: Offset(x1, y1),
          end: Offset(x2, y2),
          color: color ?? Colors.white,
          strokeWidth: width ?? 1,
        );
      case 'box':
      case 'rect':
        if (parts.length < 5) {
          return null;
        }
        final x = double.tryParse(parts[1]);
        final y = double.tryParse(parts[2]);
        final w = double.tryParse(parts[3]);
        final h = double.tryParse(parts[4]);
        if (x == null || y == null || w == null || h == null) {
          return null;
        }
        final strokeColor = parts.length > 5 ? _parseColor(parts[5]) : null;
        final fillColor = parts.length > 6 ? _parseColor(parts[6]) : null;
        final strokeWidth = parts.length > 7 ? double.tryParse(parts[7]) : null;
        return CanvasCommand.box(
          rect: Rect.fromLTWH(x, y, w, h),
          strokeColor: strokeColor ?? Colors.white,
          fillColor: fillColor,
          strokeWidth: strokeWidth ?? 1,
        );
      case 'text':
        if (parts.length < 4) {
          return null;
        }
        final x = double.tryParse(parts[1]);
        final y = double.tryParse(parts[2]);
        if (x == null || y == null) {
          return null;
        }
        var cursor = 3;
        double fontSize = 14;
        Color color = Colors.white;

        if (cursor < parts.length) {
          final sizeCandidate = double.tryParse(parts[cursor]);
          if (sizeCandidate != null) {
            fontSize = sizeCandidate;
            cursor += 1;
          }
        }

        if (cursor < parts.length) {
          final colorCandidate = _parseColor(parts[cursor]);
          if (colorCandidate != null) {
            color = colorCandidate;
            cursor += 1;
          }
        }

        if (cursor >= parts.length) {
          return null;
        }
        final text = parts.sublist(cursor).join(' ');
        return CanvasCommand.text(
          position: Offset(x, y),
          text: text,
          color: color,
          fontSize: fontSize,
        );
      default:
        return null;
    }
  }

  static Offset? _parseOffset(
      Map<String, dynamic> map, String xKey, String yKey) {
    final x = _parseDouble(map[xKey], null);
    final y = _parseDouble(map[yKey], null);
    if (x == null || y == null) {
      return null;
    }
    return Offset(x, y);
  }

  static Offset? _parsePair(dynamic value) {
    if (value is List && value.length >= 2) {
      final x = _parseDouble(value[0], null);
      final y = _parseDouble(value[1], null);
      if (x == null || y == null) {
        return null;
      }
      return Offset(x, y);
    }
    if (value is Map<String, dynamic>) {
      return _parseOffset(value, 'x', 'y');
    }
    return null;
  }

  static Rect? _parseRect(dynamic value) {
    if (value is Map<String, dynamic>) {
      final x =
          _parseDouble(value['x'], null) ?? _parseDouble(value['left'], null);
      final y =
          _parseDouble(value['y'], null) ?? _parseDouble(value['top'], null);
      final w =
          _parseDouble(value['width'], null) ?? _parseDouble(value['w'], null);
      final h =
          _parseDouble(value['height'], null) ?? _parseDouble(value['h'], null);
      if (x == null || y == null || w == null || h == null) {
        return null;
      }
      return Rect.fromLTWH(x, y, w, h);
    }
    if (value is List && value.length >= 4) {
      final x = _parseDouble(value[0], null);
      final y = _parseDouble(value[1], null);
      final w = _parseDouble(value[2], null);
      final h = _parseDouble(value[3], null);
      if (x == null || y == null || w == null || h == null) {
        return null;
      }
      return Rect.fromLTWH(x, y, w, h);
    }
    return null;
  }

  static Size? _parseSceneSize(Map<String, dynamic> map) {
    final width = _parseDouble(map['width'], null) ??
        _parseDouble(map['w'], null) ??
        _parseDouble(map['canvasWidth'], null);
    final height = _parseDouble(map['height'], null) ??
        _parseDouble(map['h'], null) ??
        _parseDouble(map['canvasHeight'], null);
    if (width != null && height != null && width > 0 && height > 0) {
      return Size(width, height);
    }
    final viewBox = map['viewBox'];
    if (viewBox is List && viewBox.length >= 4) {
      final w = _parseDouble(viewBox[2], null);
      final h = _parseDouble(viewBox[3], null);
      if (w != null && h != null && w > 0 && h > 0) {
        return Size(w, h);
      }
    }
    return null;
  }

  static double? _parseDouble(dynamic value, double? fallback) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static Color? _parseColor(dynamic value) {
    if (value is int) {
      return Color(value);
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      final named = _namedColors[trimmed.toLowerCase()];
      if (named != null) {
        return named;
      }
      final normalized =
          trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
      if (normalized.startsWith('0x')) {
        final parsed = int.tryParse(normalized.substring(2), radix: 16);
        if (parsed != null) {
          return Color(parsed);
        }
      }
      if (normalized.length == 6 || normalized.length == 8) {
        final parsed = int.tryParse(normalized, radix: 16);
        if (parsed != null) {
          return Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
        }
      }
    }
    return null;
  }
}

const Map<String, Color> _namedColors = {
  'white': Colors.white,
  'black': Colors.black,
  'red': Colors.red,
  'green': Colors.green,
  'blue': Colors.blue,
  'yellow': Colors.yellow,
  'cyan': Colors.cyan,
  'magenta': Colors.purple,
  'gray': Colors.grey,
  'grey': Colors.grey,
  'orange': Colors.orange,
  'purple': Colors.purple,
};

enum CanvasCommandType { line, box, text }

class CanvasCommand {
  CanvasCommand.line({
    required this.start,
    required this.end,
    required this.color,
    this.strokeWidth = 1,
  })  : type = CanvasCommandType.line,
        rect = null,
        text = null,
        position = null,
        fontSize = null,
        fillColor = null,
        strokeColor = null;

  CanvasCommand.box({
    required this.rect,
    required this.strokeColor,
    this.fillColor,
    this.strokeWidth = 1,
  })  : type = CanvasCommandType.box,
        start = null,
        end = null,
        text = null,
        position = null,
        fontSize = null,
        color = null;

  CanvasCommand.text({
    required this.position,
    required this.text,
    required this.color,
    this.fontSize = 14,
  })  : type = CanvasCommandType.text,
        start = null,
        end = null,
        rect = null,
        fillColor = null,
        strokeWidth = 0,
        strokeColor = null;

  final CanvasCommandType type;
  final Offset? start;
  final Offset? end;
  final Rect? rect;
  final Offset? position;
  final String? text;
  final double? fontSize;
  final Color? color;
  final Color? strokeColor;
  final Color? fillColor;
  final double strokeWidth;

  void paint(Canvas canvas) {
    switch (type) {
      case CanvasCommandType.line:
        final paint = Paint()
          ..color = color ?? Colors.white
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(start!, end!, paint);
        break;
      case CanvasCommandType.box:
        final rectValue = rect!;
        if (fillColor != null) {
          final fill = Paint()
            ..color = fillColor!
            ..style = PaintingStyle.fill;
          canvas.drawRect(rectValue, fill);
        }
        final stroke = Paint()
          ..color = strokeColor ?? Colors.white
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;
        canvas.drawRect(rectValue, stroke);
        break;
      case CanvasCommandType.text:
        final textPainter = TextPainter(
          text: TextSpan(
            text: text!,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: fontSize ?? 14,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, position!);
        break;
    }
  }
}

class CanvasInputEvent {
  const CanvasInputEvent({
    required this.type,
    required this.position,
    this.delta,
    this.phase,
    required this.timestampMs,
  });

  final String type;
  final Offset position;
  final Offset? delta;
  final String? phase;
  final int timestampMs;

  Map<String, dynamic> toJson() {
    return {
      'type': 'input_event',
      'event': type,
      'phase': phase,
      'x': position.dx,
      'y': position.dy,
      if (delta != null) 'dx': delta!.dx,
      if (delta != null) 'dy': delta!.dy,
      'ts': timestampMs,
    };
  }
}

class CanvasView extends StatefulWidget {
  const CanvasView({
    super.key,
    required this.scene,
    this.onInputEvent,
    this.backgroundColor,
  });

  final CanvasScene? scene;
  final ValueChanged<CanvasInputEvent>? onInputEvent;
  final Color? backgroundColor;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  Offset? _lastPanPosition;

  @override
  Widget build(BuildContext context) {
    final resolvedScene = widget.scene ?? CanvasScene.empty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        final transform = CanvasTransform(
          viewSize: viewSize,
          sceneSize: resolvedScene.logicalSize,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _emitInput(
            'tap',
            transform,
            details.localPosition,
            null,
            null,
          ),
          onPanStart: (details) => _emitInput(
            'pan',
            transform,
            details.localPosition,
            null,
            'start',
          ),
          onPanUpdate: (details) => _emitInput(
            'pan',
            transform,
            details.localPosition,
            details.delta,
            'update',
          ),
          onPanEnd: (_) => _emitInput(
            'pan',
            transform,
            _lastPanPosition ?? Offset.zero,
            null,
            'end',
          ),
          onPanCancel: () => _emitInput(
            'pan',
            transform,
            _lastPanPosition ?? Offset.zero,
            null,
            'cancel',
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: CanvasCommandPainter(
                    scene: resolvedScene,
                    transform: transform,
                    backgroundColor: widget.backgroundColor,
                  ),
                ),
              ),
              if (resolvedScene.isEmpty)
                Center(
                  child: Text(
                    '等待画布指令...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _emitInput(
    String type,
    CanvasTransform transform,
    Offset localPosition,
    Offset? delta,
    String? phase,
  ) {
    final handler = widget.onInputEvent;
    if (handler == null) {
      return;
    }
    _lastPanPosition = localPosition;
    final scenePosition = transform.toScene(localPosition);
    final sceneDelta = delta == null ? null : transform.toSceneDelta(delta);
    handler(
      CanvasInputEvent(
        type: type,
        phase: phase,
        position: scenePosition,
        delta: sceneDelta,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

class CanvasTransform {
  CanvasTransform({
    required this.viewSize,
    required this.sceneSize,
  }) {
    final scene = sceneSize;
    if (scene == null || scene.width <= 0 || scene.height <= 0) {
      scale = 1.0;
      offset = Offset.zero;
      return;
    }

    final sx = viewSize.width / scene.width;
    final sy = viewSize.height / scene.height;
    scale = math.min(sx, sy);
    final fittedSize = Size(scene.width * scale, scene.height * scale);
    offset = Offset(
      (viewSize.width - fittedSize.width) / 2,
      (viewSize.height - fittedSize.height) / 2,
    );
  }

  final Size viewSize;
  final Size? sceneSize;
  late final double scale;
  late final Offset offset;

  void apply(Canvas canvas) {
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale, scale);
  }

  Offset toScene(Offset local) {
    if (scale == 0) {
      return local;
    }
    return (local - offset) / scale;
  }

  Offset toSceneDelta(Offset delta) {
    if (scale == 0) {
      return delta;
    }
    return delta / scale;
  }
}

class CanvasCommandPainter extends CustomPainter {
  CanvasCommandPainter({
    required this.scene,
    required this.transform,
    this.backgroundColor,
  });

  final CanvasScene scene;
  final CanvasTransform transform;
  final Color? backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor != null) {
      final paint = Paint()
        ..color = backgroundColor!
        ..style = PaintingStyle.fill;
      canvas.drawRect(Offset.zero & size, paint);
    }

    canvas.save();
    transform.apply(canvas);
    for (final command in scene.commands) {
      command.paint(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CanvasCommandPainter oldDelegate) {
    return oldDelegate.scene != scene ||
        oldDelegate.transform.scale != transform.scale ||
        oldDelegate.transform.offset != transform.offset ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
