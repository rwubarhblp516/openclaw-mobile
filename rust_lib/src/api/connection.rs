use crate::api::events::{
    parse_gateway_frame, AgentTurn, CameraSnapshot, ExecParams, GatewayEvent, GatewayRequestFrame,
    GatewayRequestParams, LogsSubscribeParams, LogsUnsubscribeParams, SessionsCloseParams,
    SessionsListParams, SessionsSpawnParams, StreamCloseParams, StreamOpenParams, StreamSendParams,
    SystemEvent, SystemProbeParams,
};
use crate::frb_generated::StreamSink;
use crate::Duration;
use anyhow::Result;
use base64::{engine::general_purpose::STANDARD, Engine as _};
use flate2::{write::GzEncoder, Compression};
use flutter_rust_bridge::frb;
use futures_util::{SinkExt, StreamExt};
#[cfg(test)]
use futures_util::future::BoxFuture;
use serde_json::Value;
use std::collections::BTreeMap;
use std::io::Write;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::Duration as StdDuration;
use tokio::time::{sleep, Instant, MissedTickBehavior};
#[cfg(test)]
use tokio::{io::AsyncRead, io::AsyncWrite};
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};
#[cfg(test)]
use tokio_tungstenite::WebSocketStream;

type RequestSender = tokio::sync::mpsc::UnboundedSender<String>;

static OUTBOUND_REQUEST_SENDER: OnceLock<Mutex<Option<RequestSender>>> = OnceLock::new();

fn outbound_request_sender_slot() -> &'static Mutex<Option<RequestSender>> {
    OUTBOUND_REQUEST_SENDER.get_or_init(|| Mutex::new(None))
}

fn register_outbound_request_sender(sender: RequestSender) -> OutboundRequestSenderGuard {
    let slot = outbound_request_sender_slot();
    if let Ok(mut guard) = slot.lock() {
        *guard = Some(sender);
    }
    OutboundRequestSenderGuard {}
}

fn try_get_outbound_request_sender() -> Option<RequestSender> {
    outbound_request_sender_slot()
        .lock()
        .ok()
        .and_then(|guard| guard.clone())
}

struct OutboundRequestSenderGuard {}

impl Drop for OutboundRequestSenderGuard {
    fn drop(&mut self) {
        if let Ok(mut guard) = outbound_request_sender_slot().lock() {
            *guard = None;
        }
    }
}

pub struct GatewayClient {
    pub url: String,
}

static REQUEST_COUNTER: AtomicU64 = AtomicU64::new(1);

impl GatewayClient {
    pub fn new(url: String) -> Self {
        Self { url }
    }

    #[frb(sync)]
    pub fn get_url(&self) -> String {
        self.url.clone()
    }

    #[frb(sync)]
    pub fn next_request_id(&self) -> String {
        next_request_id("req")
    }

    pub fn sessions_list_request(
        &self,
        request_id: String,
        limit: Option<u32>,
        cursor: Option<String>,
        session_key: Option<String>,
    ) -> Result<String> {
        let params = SessionsListParams {
            limit,
            cursor,
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "sessions.list",
            GatewayRequestParams::SessionsList(params),
            session_key,
        )
    }

    pub fn sessions_spawn_request(
        &self,
        request_id: String,
        parent_session_key: Option<String>,
        label: Option<String>,
        metadata_json: Option<String>,
        session_key: Option<String>,
    ) -> Result<String> {
        let metadata = parse_metadata(metadata_json)?;
        let params = SessionsSpawnParams {
            parent_session_key,
            label,
            metadata,
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "sessions.spawn",
            GatewayRequestParams::SessionsSpawn(params),
            session_key,
        )
    }

    pub fn sessions_close_request(
        &self,
        request_id: String,
        session_key: String,
        reason: Option<String>,
        metadata_json: Option<String>,
    ) -> Result<String> {
        let mut metadata = parse_metadata(metadata_json)?.unwrap_or_default();
        metadata
            .entry("archive".to_string())
            .or_insert(Value::Bool(true));

        let params = SessionsCloseParams {
            session_key: session_key.clone(),
            reason,
            archive: true,
            metadata: Some(metadata),
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "sessions.close",
            GatewayRequestParams::SessionsClose(params),
            Some(session_key),
        )
    }

    pub fn camera_snap_request(
        &self,
        request_id: String,
        frame_bytes: Vec<u8>,
        format: Option<String>,
        width: Option<u32>,
        height: Option<u32>,
        timestamp_ms: Option<i64>,
        compress: bool,
        session_key: Option<String>,
    ) -> Result<String> {
        let snapshot =
            encode_camera_snapshot(frame_bytes, format, width, height, timestamp_ms, compress)?;
        build_request_json(
            request_id,
            "camera_snap",
            GatewayRequestParams::CameraSnapshot(snapshot),
            session_key,
        )
    }

    pub fn exec_request(
        &self,
        request_id: String,
        command: String,
        args: Vec<String>,
        cwd: Option<String>,
        env_json: Option<String>,
        stdin: Option<String>,
        timeout_ms: Option<u64>,
        stream: Option<bool>,
        exec_id: Option<String>,
        kill_on_drop: Option<bool>,
        session_key: Option<String>,
    ) -> Result<String> {
        let env = parse_metadata(env_json)?;
        let params = ExecParams {
            command,
            args,
            cwd,
            env,
            stdin,
            timeout_ms,
            stream,
            exec_id,
            kill_on_drop,
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "exec",
            GatewayRequestParams::Exec(params),
            session_key,
        )
    }

    pub fn exec_command_request(
        &self,
        request_id: String,
        command: String,
        args: Vec<String>,
        stdin_bytes: Option<Vec<u8>>,
        cwd: Option<String>,
        env_json: Option<String>,
        timeout_ms: Option<u64>,
        exec_id: Option<String>,
        kill_on_drop: Option<bool>,
        pty: Option<bool>,
        cols: Option<u32>,
        rows: Option<u32>,
        term: Option<String>,
        permissions_json: Option<String>,
        session_key: Option<String>,
    ) -> Result<String> {
        ensure_elevated_permission(permissions_json)?;
        let env = parse_metadata(env_json)?;
        let mut extra = BTreeMap::new();
        if let Some(value) = pty {
            extra.insert("pty".to_string(), Value::Bool(value));
        }
        if let Some(value) = cols {
            extra.insert("cols".to_string(), Value::Number(value.into()));
        }
        if let Some(value) = rows {
            extra.insert("rows".to_string(), Value::Number(value.into()));
        }
        if let Some(value) = term {
            extra.insert("term".to_string(), Value::String(value));
        }

        let stdin = stdin_bytes.map(|bytes| STANDARD.encode(bytes));
        if stdin.is_some() {
            extra.insert(
                "stdinEncoding".to_string(),
                Value::String("base64".to_string()),
            );
        }

        let params = ExecParams {
            command,
            args,
            cwd,
            env,
            stdin,
            timeout_ms,
            stream: Some(true),
            exec_id,
            kill_on_drop,
            extra,
        };
        build_request_json(
            request_id,
            "exec",
            GatewayRequestParams::Exec(params),
            session_key,
        )
    }

    pub fn interactive_shell_open_request(
        &self,
        request_id: String,
        cols: Option<u32>,
        rows: Option<u32>,
        term: Option<String>,
        metadata_json: Option<String>,
        permissions_json: Option<String>,
        session_key: Option<String>,
    ) -> Result<String> {
        ensure_elevated_permission(permissions_json)?;
        let metadata = parse_metadata(metadata_json)?;
        let params = StreamOpenParams {
            stream: "interactive_shell".to_string(),
            term,
            cols,
            rows,
            metadata,
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "streams.open",
            GatewayRequestParams::StreamOpen(params),
            session_key,
        )
    }

    pub fn interactive_shell_send_request(
        &self,
        request_id: String,
        stream_id: Option<String>,
        input_bytes: Vec<u8>,
        channel: Option<String>,
        permissions_json: Option<String>,
        session_key: Option<String>,
    ) -> Result<String> {
        ensure_elevated_permission(permissions_json)?;
        let data = STANDARD.encode(input_bytes);
        let params = StreamSendParams {
            stream: "interactive_shell".to_string(),
            stream_id,
            channel: Some(channel.unwrap_or_else(|| "stdin".to_string())),
            event: None,
            data: Some(data),
            encoding: Some("base64".to_string()),
            cols: None,
            rows: None,
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "streams.send",
            GatewayRequestParams::StreamSend(params),
            session_key,
        )
    }

    pub fn interactive_shell_resize_request(
        &self,
        request_id: String,
        stream_id: Option<String>,
        cols: u32,
        rows: u32,
        permissions_json: Option<String>,
        session_key: Option<String>,
    ) -> Result<String> {
        ensure_elevated_permission(permissions_json)?;
        let params = StreamSendParams {
            stream: "interactive_shell".to_string(),
            stream_id,
            channel: None,
            event: Some("resize".to_string()),
            data: None,
            encoding: None,
            cols: Some(cols),
            rows: Some(rows),
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "streams.send",
            GatewayRequestParams::StreamSend(params),
            session_key,
        )
    }

    pub fn interactive_shell_close_request(
        &self,
        request_id: String,
        stream_id: Option<String>,
        reason: Option<String>,
        permissions_json: Option<String>,
        session_key: Option<String>,
    ) -> Result<String> {
        ensure_elevated_permission(permissions_json)?;
        let params = StreamCloseParams {
            stream: "interactive_shell".to_string(),
            stream_id,
            reason,
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "streams.close",
            GatewayRequestParams::StreamClose(params),
            session_key,
        )
    }

    pub fn logs_subscribe_request(
        &self,
        request_id: String,
        level: Option<String>,
        tail: Option<u32>,
        since: Option<i64>,
        include_internal: Option<bool>,
        filters_json: Option<String>,
        session_key: Option<String>,
    ) -> Result<String> {
        let filters = parse_metadata(filters_json)?;
        let params = LogsSubscribeParams {
            level,
            tail,
            since,
            include_internal,
            filters,
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "logs.subscribe",
            GatewayRequestParams::LogsSubscribe(params),
            session_key,
        )
    }

    pub fn logs_unsubscribe_request(
        &self,
        request_id: String,
        subscription_id: Option<String>,
        session_key: Option<String>,
    ) -> Result<String> {
        let params = LogsUnsubscribeParams {
            subscription_id,
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "logs.unsubscribe",
            GatewayRequestParams::LogsUnsubscribe(params),
            session_key,
        )
    }

    pub fn system_probe_request(
        &self,
        request_id: String,
        network: Option<bool>,
        disk: Option<bool>,
        gateway: Option<bool>,
        session_key: Option<String>,
    ) -> Result<String> {
        let params = SystemProbeParams {
            network,
            disk,
            gateway,
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "system.probe",
            GatewayRequestParams::SystemProbe(params),
            session_key,
        )
    }

    pub fn agent_turn_request(
        &self,
        request_id: String,
        message: String,
        model: Option<String>,
        thinking: Option<String>,
        timeout_seconds: Option<u64>,
        session_key: Option<String>,
    ) -> Result<String> {
        let params = AgentTurn {
            message,
            model,
            thinking,
            timeout_seconds,
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "agent",
            GatewayRequestParams::AgentTurn(params),
            session_key,
        )
    }

    pub fn system_event_request(
        &self,
        request_id: String,
        text: Option<String>,
        mode: Option<String>,
        session_key: Option<String>,
    ) -> Result<String> {
        let params = SystemEvent {
            text,
            session_key: session_key.clone(),
            mode,
            extra: BTreeMap::new(),
        };
        build_request_json(
            request_id,
            "system-event",
            GatewayRequestParams::SystemEvent(params),
            session_key,
        )
    }
}

pub fn send_gateway_request_frame(frame_json: String) -> Result<()> {
    let frame: GatewayRequestFrame = serde_json::from_str(frame_json.trim())?;
    if frame.frame_type != "req" {
        return Err(anyhow::anyhow!(
            "Only GatewayRequestFrame payloads with type=req can be sent"
        ));
    }

    let sender = try_get_outbound_request_sender()
        .ok_or_else(|| anyhow::anyhow!("Gateway is not connected"))?;
    let payload = frame.to_json()?;
    sender
        .send(payload)
        .map_err(|_| anyhow::anyhow!("Failed to send request: connection is closed"))?;
    Ok(())
}

fn next_request_id(prefix: &str) -> String {
    let id = REQUEST_COUNTER.fetch_add(1, Ordering::Relaxed);
    format!("{prefix}-{id}")
}

fn build_request_json(
    request_id: String,
    method: &str,
    params: GatewayRequestParams,
    session_key: Option<String>,
) -> Result<String> {
    let frame = GatewayRequestFrame::new(request_id, method, params, session_key);
    Ok(frame.to_json()?)
}

fn parse_metadata(metadata_json: Option<String>) -> Result<Option<BTreeMap<String, Value>>> {
    let Some(metadata_json) = metadata_json else {
        return Ok(None);
    };
    let trimmed = metadata_json.trim();
    if trimmed.is_empty() {
        return Ok(None);
    }
    let value: Value = serde_json::from_str(trimmed)?;
    if value.is_null() {
        return Ok(None);
    }
    let map = value
        .as_object()
        .ok_or_else(|| anyhow::anyhow!("metadata must be a JSON object"))?;
    let mut metadata = BTreeMap::new();
    for (key, value) in map {
        metadata.insert(key.clone(), value.clone());
    }
    Ok(Some(metadata))
}

fn ensure_elevated_permission(permissions_json: Option<String>) -> Result<()> {
    let Some(permissions_json) = permissions_json else {
        return Err(anyhow::anyhow!(
            "Shell access requires elevated permission."
        ));
    };
    let value: Value = serde_json::from_str(permissions_json.trim())?;
    let object = value
        .as_object()
        .ok_or_else(|| anyhow::anyhow!("permissions must be a JSON object"))?;
    let elevated = object
        .get("elevated")
        .and_then(|value| value.as_bool())
        .unwrap_or(false);
    if !elevated {
        return Err(anyhow::anyhow!(
            "Shell access requires elevated permission."
        ));
    }
    Ok(())
}

fn encode_camera_snapshot(
    frame_bytes: Vec<u8>,
    format: Option<String>,
    width: Option<u32>,
    height: Option<u32>,
    timestamp_ms: Option<i64>,
    compress: bool,
) -> Result<CameraSnapshot> {
    let (data, compression) = encode_frame_bytes(&frame_bytes, compress)?;
    Ok(CameraSnapshot {
        data,
        encoding: "base64".to_string(),
        compression,
        format,
        width,
        height,
        timestamp_ms,
        extra: BTreeMap::new(),
    })
}

fn encode_frame_bytes(frame_bytes: &[u8], compress: bool) -> Result<(String, Option<String>)> {
    if compress {
        let mut encoder = GzEncoder::new(Vec::new(), Compression::fast());
        encoder.write_all(frame_bytes)?;
        let compressed = encoder.finish()?;
        Ok((STANDARD.encode(compressed), Some("gzip".to_string())))
    } else {
        Ok((STANDARD.encode(frame_bytes), None))
    }
}

pub async fn connect_to_gateway(url: String, sink: StreamSink<GatewayEvent>) -> Result<()> {
    connect_to_gateway_with_sink(url, sink, ConnectionConfig::default()).await
}

#[derive(Clone, Copy)]
#[frb(ignore)]
pub(crate) struct ConnectionConfig {
    pub(crate) backoff_base: Duration,
    pub(crate) max_backoff: Duration,
    pub(crate) heartbeat_interval: Duration,
    pub(crate) heartbeat_timeout: Duration,
    pub(crate) max_sessions: Option<u32>,
}

impl Default for ConnectionConfig {
    fn default() -> Self {
        Self {
            backoff_base: Duration::milliseconds(500),
            max_backoff: Duration::seconds(10),
            heartbeat_interval: Duration::seconds(10),
            heartbeat_timeout: Duration::seconds(30),
            max_sessions: None,
        }
    }
}

trait EventSink {
    fn add_event(&self, event: GatewayEvent) -> bool;
}

impl EventSink for StreamSink<GatewayEvent> {
    fn add_event(&self, event: GatewayEvent) -> bool {
        self.add(event).is_ok()
    }
}

#[cfg(test)]
#[frb(ignore)]
pub(crate) trait Connector {
    type Stream: AsyncRead + AsyncWrite + Unpin + Send + 'static;
    fn connect(&self, url: String) -> BoxFuture<'static, Result<WebSocketStream<Self::Stream>>>;
}

#[cfg(test)]
#[frb(ignore)]
pub(crate) struct DefaultConnector {}

#[cfg(test)]
impl Connector for DefaultConnector {
    type Stream = tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>;

    fn connect(&self, url: String) -> BoxFuture<'static, Result<WebSocketStream<Self::Stream>>> {
        Box::pin(async move {
            let (ws_stream, _) = connect_async(url).await?;
            Ok(ws_stream)
        })
    }
}

async fn connect_to_gateway_with_sink<S: EventSink>(
    url: String,
    sink: S,
    config: ConnectionConfig,
) -> Result<()> {
    let backoff_base = duration_to_std(config.backoff_base);
    let max_backoff = duration_to_std(config.max_backoff);
    let heartbeat_interval = duration_to_std(config.heartbeat_interval);
    let heartbeat_timeout = duration_to_std(config.heartbeat_timeout);
    let mut backoff = backoff_base;
    let mut attempt: u32 = 0;
    let mut sessions_completed: u32 = 0;

    loop {
        match connect_async(url.clone()).await {
            Ok((ws_stream, _)) => {
                attempt = 0;
                backoff = backoff_base;
                if !try_emit(&sink, GatewayEvent::Connected) {
                    return Ok(());
                }

                let (mut write, mut read) = ws_stream.split();
                let (request_tx, mut request_rx) = tokio::sync::mpsc::unbounded_channel::<String>();
                let _request_sender_guard = register_outbound_request_sender(request_tx);
                let mut heartbeat = tokio::time::interval(heartbeat_interval);
                heartbeat.set_missed_tick_behavior(MissedTickBehavior::Delay);
                let mut last_received = Instant::now();
                let mut disconnect_reason = "Connection closed".to_string();

                loop {
                    tokio::select! {
                        msg = read.next() => {
                            match msg {
                                Some(Ok(Message::Text(text))) => {
                                    last_received = Instant::now();
                                    let event = parse_gateway_frame(&text)
                                        .unwrap_or_else(|| GatewayEvent::Message {
                                            message: text.to_string(),
                                        });
                                    if !try_emit(&sink, event) {
                                        return Ok(());
                                    }
                                }
                                Some(Ok(Message::Ping(payload))) => {
                                    last_received = Instant::now();
                                    if let Err(e) = write.send(Message::Pong(payload)).await {
                                        disconnect_reason = format!("WebSocket pong error: {e}");
                                        if !try_emit(
                                            &sink,
                                            GatewayEvent::Error {
                                                message: e.to_string(),
                                            },
                                        ) {
                                            return Ok(());
                                        }
                                        break;
                                    }
                                }
                                Some(Ok(Message::Pong(_))) => {
                                    last_received = Instant::now();
                                }
                                Some(Ok(Message::Binary(data))) => {
                                    last_received = Instant::now();
                                    if !try_emit(
                                        &sink,
                                        GatewayEvent::Binary {
                                            data: data.to_vec(),
                                        },
                                    ) {
                                        return Ok(());
                                    }
                                }
                                Some(Ok(Message::Close(frame))) => {
                                    disconnect_reason = frame
                                        .map(|f| {
                                            if f.reason.is_empty() {
                                                "Server closed connection".to_string()
                                            } else {
                                                f.reason.to_string()
                                            }
                                        })
                                        .unwrap_or_else(|| "Server closed connection".to_string());
                                    break;
                                }
                                Some(Err(e)) => {
                                    disconnect_reason = format!("WebSocket error: {e}");
                                    if !try_emit(
                                        &sink,
                                        GatewayEvent::Error {
                                            message: e.to_string(),
                                        },
                                    ) {
                                        return Ok(());
                                    }
                                    break;
                                }
                                None => {
                                    disconnect_reason = "Connection closed".to_string();
                                    break;
                                }
                                _ => {}
                            }
                        }
                        outbound = request_rx.recv() => {
                            match outbound {
                                Some(payload) => {
                                    if let Err(e) = write.send(Message::Text(payload.into())).await {
                                        disconnect_reason = format!("Request send error: {e}");
                                        if !try_emit(
                                            &sink,
                                            GatewayEvent::Error {
                                                message: e.to_string(),
                                            },
                                        ) {
                                            return Ok(());
                                        }
                                        break;
                                    }
                                }
                                None => {
                                    disconnect_reason = "Request channel closed".to_string();
                                    break;
                                }
                            }
                        }
                        _ = heartbeat.tick() => {
                            if last_received.elapsed() >= heartbeat_timeout {
                                disconnect_reason = "Heartbeat timeout".to_string();
                                break;
                            }
                            if let Err(e) = write.send(Message::Ping(Vec::new().into())).await {
                                disconnect_reason = format!("Heartbeat send error: {e}");
                                if !try_emit(
                                    &sink,
                                    GatewayEvent::Error {
                                        message: e.to_string(),
                                    },
                                ) {
                                    return Ok(());
                                }
                                break;
                            }
                        }
                    }
                }

                if !try_emit(
                    &sink,
                    GatewayEvent::Disconnected {
                        reason: disconnect_reason,
                    },
                ) {
                    return Ok(());
                }

                sessions_completed = sessions_completed.saturating_add(1);
                if let Some(max_sessions) = config.max_sessions {
                    if sessions_completed >= max_sessions {
                        return Ok(());
                    }
                }
            }
            Err(e) => {
                let error_message = format!("Connect failed (attempt {}): {e}", attempt + 1);
                if !try_emit(
                    &sink,
                    GatewayEvent::Error {
                        message: error_message.clone(),
                    },
                ) {
                    return Ok(());
                }
                if !try_emit(
                    &sink,
                    GatewayEvent::Disconnected {
                        reason: error_message,
                    },
                ) {
                    return Ok(());
                }
            }
        }

        attempt = attempt.saturating_add(1);
        sleep(backoff).await;
        backoff = std::cmp::min(backoff.checked_mul(2).unwrap_or(max_backoff), max_backoff);
    }
}

#[cfg(test)]
async fn connect_to_gateway_with_sink_and_connector<S: EventSink, C: Connector>(
    url: String,
    sink: S,
    config: ConnectionConfig,
    connector: &C,
) -> Result<()> {
    let backoff_base = duration_to_std(config.backoff_base);
    let max_backoff = duration_to_std(config.max_backoff);
    let heartbeat_interval = duration_to_std(config.heartbeat_interval);
    let heartbeat_timeout = duration_to_std(config.heartbeat_timeout);
    let mut backoff = backoff_base;
    let mut attempt: u32 = 0;
    let mut sessions_completed: u32 = 0;

    loop {
        match connector.connect(url.clone()).await {
            Ok(ws_stream) => {
                attempt = 0;
                backoff = backoff_base;
                if !try_emit(&sink, GatewayEvent::Connected) {
                    return Ok(());
                }

                let (mut write, mut read) = ws_stream.split();
                let (request_tx, mut request_rx) = tokio::sync::mpsc::unbounded_channel::<String>();
                let _request_sender_guard = register_outbound_request_sender(request_tx);
                let mut heartbeat = tokio::time::interval(heartbeat_interval);
                heartbeat.set_missed_tick_behavior(MissedTickBehavior::Delay);
                let mut last_received = Instant::now();
                let mut disconnect_reason = "Connection closed".to_string();

                loop {
                    tokio::select! {
                        msg = read.next() => {
                            match msg {
                                Some(Ok(Message::Text(text))) => {
                                    last_received = Instant::now();
                                    let event = parse_gateway_frame(&text)
                                        .unwrap_or_else(|| GatewayEvent::Message {
                                            message: text.to_string(),
                                        });
                                    if !try_emit(&sink, event) {
                                        return Ok(());
                                    }
                                }
                                Some(Ok(Message::Ping(payload))) => {
                                    last_received = Instant::now();
                                    if let Err(e) = write.send(Message::Pong(payload)).await {
                                        disconnect_reason = format!("WebSocket pong error: {e}");
                                        if !try_emit(
                                            &sink,
                                            GatewayEvent::Error {
                                                message: e.to_string(),
                                            },
                                        ) {
                                            return Ok(());
                                        }
                                        break;
                                    }
                                }
                                Some(Ok(Message::Pong(_))) => {
                                    last_received = Instant::now();
                                }
                                Some(Ok(Message::Binary(data))) => {
                                    last_received = Instant::now();
                                    if !try_emit(
                                        &sink,
                                        GatewayEvent::Binary {
                                            data: data.to_vec(),
                                        },
                                    ) {
                                        return Ok(());
                                    }
                                }
                                Some(Ok(Message::Close(frame))) => {
                                    disconnect_reason = frame
                                        .map(|f| {
                                            if f.reason.is_empty() {
                                                "Server closed connection".to_string()
                                            } else {
                                                f.reason.to_string()
                                            }
                                        })
                                        .unwrap_or_else(|| "Server closed connection".to_string());
                                    break;
                                }
                                Some(Err(e)) => {
                                    disconnect_reason = format!("WebSocket error: {e}");
                                    if !try_emit(
                                        &sink,
                                        GatewayEvent::Error {
                                            message: e.to_string(),
                                        },
                                    ) {
                                        return Ok(());
                                    }
                                    break;
                                }
                                None => {
                                    disconnect_reason = "Connection closed".to_string();
                                    break;
                                }
                                _ => {}
                            }
                        }
                        outbound = request_rx.recv() => {
                            match outbound {
                                Some(payload) => {
                                    if let Err(e) = write.send(Message::Text(payload.into())).await {
                                        disconnect_reason = format!("Request send error: {e}");
                                        if !try_emit(
                                            &sink,
                                            GatewayEvent::Error {
                                                message: e.to_string(),
                                            },
                                        ) {
                                            return Ok(());
                                        }
                                        break;
                                    }
                                }
                                None => {
                                    disconnect_reason = "Request channel closed".to_string();
                                    break;
                                }
                            }
                        }
                        _ = heartbeat.tick() => {
                            if last_received.elapsed() >= heartbeat_timeout {
                                disconnect_reason = "Heartbeat timeout".to_string();
                                break;
                            }
                            if let Err(e) = write.send(Message::Ping(Vec::new().into())).await {
                                disconnect_reason = format!("Heartbeat send error: {e}");
                                if !try_emit(
                                    &sink,
                                    GatewayEvent::Error {
                                        message: e.to_string(),
                                    },
                                ) {
                                    return Ok(());
                                }
                                break;
                            }
                        }
                    }
                }

                if !try_emit(
                    &sink,
                    GatewayEvent::Disconnected {
                        reason: disconnect_reason,
                    },
                ) {
                    return Ok(());
                }

                sessions_completed = sessions_completed.saturating_add(1);
                if let Some(max_sessions) = config.max_sessions {
                    if sessions_completed >= max_sessions {
                        return Ok(());
                    }
                }
            }
            Err(e) => {
                let error_message = format!("Connect failed (attempt {}): {e}", attempt + 1);
                if !try_emit(
                    &sink,
                    GatewayEvent::Error {
                        message: error_message.clone(),
                    },
                ) {
                    return Ok(());
                }
                if !try_emit(
                    &sink,
                    GatewayEvent::Disconnected {
                        reason: error_message,
                    },
                ) {
                    return Ok(());
                }
            }
        }

        attempt = attempt.saturating_add(1);
        sleep(backoff).await;
        backoff = std::cmp::min(backoff.checked_mul(2).unwrap_or(max_backoff), max_backoff);
    }
}

fn duration_to_std(duration: Duration) -> StdDuration {
    duration.to_std().unwrap_or(StdDuration::ZERO)
}

fn try_emit<S: EventSink>(sink: &S, event: GatewayEvent) -> bool {
    sink.add_event(event)
}

#[cfg(test)]
struct TestSink {
    sender: tokio::sync::mpsc::UnboundedSender<GatewayEvent>,
}

#[cfg(test)]
impl TestSink {
    fn new(sender: tokio::sync::mpsc::UnboundedSender<GatewayEvent>) -> Self {
        Self { sender }
    }
}

#[cfg(test)]
impl EventSink for TestSink {
    fn add_event(&self, event: GatewayEvent) -> bool {
        self.sender.send(event).is_ok()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use futures_util::SinkExt;
    use std::collections::VecDeque;
    use std::sync::Arc;
    use tokio::io::DuplexStream;
    use tokio::sync::{mpsc, Mutex};
    use tokio::time::{timeout, Duration as WaitDuration};
    use tokio_tungstenite::tungstenite::protocol::Role;

    async fn collect_event(
        receiver: &mut mpsc::UnboundedReceiver<GatewayEvent>,
        max_wait: WaitDuration,
    ) -> Option<GatewayEvent> {
        timeout(max_wait, receiver.recv()).await.ok().flatten()
    }

    struct TestConnector {
        streams: Arc<Mutex<VecDeque<DuplexStream>>>,
    }

    impl TestConnector {
        fn new(streams: Vec<DuplexStream>) -> Self {
            Self {
                streams: Arc::new(Mutex::new(streams.into())),
            }
        }
    }

    impl Connector for TestConnector {
        type Stream = DuplexStream;

        fn connect(
            &self,
            _url: String,
        ) -> BoxFuture<'static, Result<WebSocketStream<Self::Stream>>> {
            let streams = Arc::clone(&self.streams);
            Box::pin(async move {
                let mut guard = streams.lock().await;
                let stream = guard
                    .pop_front()
                    .ok_or_else(|| anyhow::anyhow!("no more streams"))?;
                Ok(WebSocketStream::from_raw_socket(stream, Role::Client, None).await)
            })
        }
    }

    #[tokio::test]
    async fn reconnects_after_disconnect() {
        let (client1, server1) = tokio::io::duplex(1024);
        let (client2, server2) = tokio::io::duplex(1024);
        let connector = TestConnector::new(vec![client1, client2]);

        let server_task = tokio::spawn(async move {
            for server_stream in [server1, server2] {
                let mut ws_stream =
                    WebSocketStream::from_raw_socket(server_stream, Role::Server, None).await;
                ws_stream.send(Message::Close(None)).await.expect("close");
            }
        });

        let (tx, mut rx) = mpsc::unbounded_channel();
        let sink = TestSink::new(tx);

        let client_task = tokio::spawn(async move {
            let config = ConnectionConfig {
                backoff_base: Duration::milliseconds(10),
                max_backoff: Duration::milliseconds(40),
                heartbeat_interval: Duration::milliseconds(50),
                heartbeat_timeout: Duration::milliseconds(200),
                max_sessions: Some(2),
            };
            connect_to_gateway_with_sink_and_connector(
                "ws://test".to_string(),
                sink,
                config,
                &connector,
            )
            .await
            .expect("client");
        });

        let mut connected_count = 0;
        let mut disconnected_count = 0;

        while connected_count < 2 {
            let event = collect_event(&mut rx, WaitDuration::from_secs(1))
                .await
                .expect("event");
            match event {
                GatewayEvent::Connected => connected_count += 1,
                GatewayEvent::Disconnected { .. } => disconnected_count += 1,
                _ => {}
            }
        }

        assert!(disconnected_count >= 1);
        let _ = client_task.await;
        let _ = server_task.await;
    }

    #[tokio::test]
    async fn heartbeat_timeout_disconnects() {
        let (client, server) = tokio::io::duplex(1024);
        let connector = TestConnector::new(vec![client]);

        let server_task = tokio::spawn(async move {
            let mut ws_stream = WebSocketStream::from_raw_socket(server, Role::Server, None).await;
            tokio::time::sleep(WaitDuration::from_millis(300)).await;
            let _ = ws_stream.send(Message::Close(None)).await;
        });

        let (tx, mut rx) = mpsc::unbounded_channel();
        let sink = TestSink::new(tx);

        let client_task = tokio::spawn(async move {
            let config = ConnectionConfig {
                backoff_base: Duration::milliseconds(10),
                max_backoff: Duration::milliseconds(40),
                heartbeat_interval: Duration::milliseconds(50),
                heartbeat_timeout: Duration::milliseconds(120),
                max_sessions: Some(1),
            };
            connect_to_gateway_with_sink_and_connector(
                "ws://test".to_string(),
                sink,
                config,
                &connector,
            )
            .await
            .expect("client");
        });

        let mut saw_disconnect = false;
        while let Some(event) = collect_event(&mut rx, WaitDuration::from_secs(1)).await {
            if let GatewayEvent::Disconnected { reason } = event {
                assert!(reason.contains("Heartbeat"), "reason: {reason}");
                saw_disconnect = true;
                break;
            }
        }

        assert!(saw_disconnect, "expected heartbeat disconnect");
        let _ = client_task.await;
        let _ = server_task.await;
    }
}
