import 'dart:async';

import 'package:openclaw_mobile/src/rust/api/events.dart';
import 'package:openclaw_mobile/src/services/gateway_service.dart';

class MockGatewayService implements GatewayService {
  StreamController<GatewayEvent>? _controller;
  String? lastUrl;
  String? lastSentFrame;

  @override
  Stream<GatewayEvent> connect({required String url}) {
    lastUrl = url;
    _controller?.close();
    _controller = StreamController<GatewayEvent>.broadcast();
    return _controller!.stream;
  }

  void emitConnected() {
    _emit(const MockGatewayEventConnected());
  }

  void emitDisconnected(String reason) {
    _emit(MockGatewayEventDisconnected(reason));
  }

  void emitMessage(String message) {
    _emit(MockGatewayEventMessage(message));
  }

  void emitError(String message) {
    _emit(MockGatewayEventError(message));
  }

  @override
  Future<void> sendRequest(String frameJson) async {
    lastSentFrame = frameJson;
  }

  void close() {
    _controller?.close();
  }

  void _emit(GatewayEvent event) {
    final controller = _controller;
    if (controller == null || controller.isClosed) {
      throw StateError('MockGatewayService is not connected.');
    }
    controller.add(event);
  }
}

abstract class MockGatewayEvent implements GatewayEvent {
  const MockGatewayEvent();

  @override
  bool get isDisposed => false;

  @override
  void dispose() {}
}

class MockGatewayEventConnected extends MockGatewayEvent {
  const MockGatewayEventConnected();

  @override
  String toString() => 'GatewayEvent.connected()';
}

class MockGatewayEventDisconnected extends MockGatewayEvent {
  const MockGatewayEventDisconnected(this.reason);

  final String reason;

  @override
  String toString() => 'GatewayEvent.disconnected(field0: $reason)';
}

class MockGatewayEventMessage extends MockGatewayEvent {
  const MockGatewayEventMessage(this.message);

  final String message;

  @override
  String toString() => 'GatewayEvent.message(field0: $message)';
}

class MockGatewayEventError extends MockGatewayEvent {
  const MockGatewayEventError(this.message);

  final String message;

  @override
  String toString() => 'GatewayEvent.error(field0: $message)';
}
