import 'package:openclaw_mobile/src/rust/api/connection.dart';
import 'package:openclaw_mobile/src/rust/api/events.dart';
abstract class GatewayService {
  Stream<GatewayEvent> connect({required String url});
  Future<void> sendRequest(String frameJson);
}
class RustGatewayService implements GatewayService {
  const RustGatewayService();
  @override
  Stream<GatewayEvent> connect({required String url}) {
    return connectToGateway(url: url);
  }
  @override
  Future<void> sendRequest(String frameJson) {
    return sendGatewayRequestFrame(frameJson: frameJson);
  }
}
