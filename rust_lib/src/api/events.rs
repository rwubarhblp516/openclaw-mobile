use crate::frb_generated::{SseDecode, SseEncode};
use flutter_rust_bridge::frb;
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct AgentTurn {
    pub message: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub thinking: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub timeout_seconds: Option<u64>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SystemEvent {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub text: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub session_key: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub mode: Option<String>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct SessionsListParams {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub limit: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cursor: Option<String>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct SessionsSpawnParams {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub parent_session_key: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub label: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub metadata: Option<BTreeMap<String, Value>>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SessionsCloseParams {
    pub session_key: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
    #[serde(default)]
    pub archive: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub metadata: Option<BTreeMap<String, Value>>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

impl Default for SessionsCloseParams {
    fn default() -> Self {
        Self {
            session_key: String::new(),
            reason: None,
            archive: true,
            metadata: None,
            extra: BTreeMap::new(),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct StreamOpenParams {
    pub stream: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub term: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cols: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rows: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub metadata: Option<BTreeMap<String, Value>>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct StreamSendParams {
    pub stream: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stream_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub channel: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub event: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub data: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub encoding: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cols: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rows: Option<u32>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct StreamCloseParams {
    pub stream: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stream_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct GatewayRequestFrame {
    #[serde(rename = "type")]
    pub frame_type: String,
    pub id: String,
    pub method: String,
    pub params: GatewayRequestParams,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub session_key: Option<String>,
}

impl GatewayRequestFrame {
    pub fn new(
        id: String,
        method: impl Into<String>,
        params: GatewayRequestParams,
        session_key: Option<String>,
    ) -> Self {
        Self {
            frame_type: "req".to_string(),
            id,
            method: method.into(),
            params,
            session_key,
        }
    }

    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ConnectParams {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub min_protocol: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub max_protocol: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub client: Option<ConnectClient>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub role: Option<String>,
    #[serde(default)]
    pub scopes: Vec<String>,
    #[serde(default)]
    pub caps: Vec<String>,
    #[serde(default)]
    pub commands: Vec<String>,
    #[serde(default)]
    pub permissions: BTreeMap<String, bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub auth: Option<ConnectAuth>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub locale: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub user_agent: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub device: Option<ConnectDevice>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ConnectClient {
    pub id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub version: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub platform: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub mode: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub display_name: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub device_family: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub model_identifier: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub instance_id: Option<String>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ConnectAuth {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub token: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub password: Option<String>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ConnectDevice {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub public_key: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub signature: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub signed_at: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub nonce: Option<String>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
#[frb(unignore)]
pub struct ConnectChallenge {
    pub nonce: String,
    pub ts: i64,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct HelloOk {
    #[serde(rename = "type")]
    pub payload_type: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub protocol: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub policy: Option<HelloPolicy>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub auth: Option<HelloAuth>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct HelloPolicy {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tick_interval_ms: Option<u64>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct HelloAuth {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub device_token: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub role: Option<String>,
    #[serde(default)]
    pub scopes: Vec<String>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
#[frb(unignore)]
pub struct PresenceEntry {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub instance_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub host: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ip: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub version: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub device_family: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub model_identifier: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub mode: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub last_input_seconds: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ts: Option<i64>,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
#[frb(unignore)]
pub struct PresenceEvent {
    #[serde(default)]
    pub entries: Vec<PresenceEntry>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
#[frb(unignore)]
pub struct ShutdownEvent {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub restart_expected_ms: Option<u64>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
#[frb(unignore)]
pub struct CameraSnapshot {
    pub data: String,
    pub encoding: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub compression: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub format: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub width: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub height: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub timestamp_ms: Option<i64>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ExecParams {
    #[serde(alias = "cmd", alias = "program")]
    pub command: String,
    #[serde(default)]
    pub args: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cwd: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub env: Option<BTreeMap<String, Value>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stdin: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub timeout_ms: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stream: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub exec_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub kill_on_drop: Option<bool>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
#[frb(unignore)]
pub struct ExecOutput {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub exec_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stream: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub data: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub encoding: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub eof: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub exit_code: Option<i32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub timestamp_ms: Option<i64>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
#[frb(unignore)]
pub struct StreamDataEvent {
    pub stream: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stream_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub channel: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub data: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub encoding: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cols: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rows: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub timestamp_ms: Option<i64>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
#[frb(unignore)]
pub struct StreamClosedEvent {
    pub stream: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stream_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub exit_code: Option<i32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct LogsSubscribeParams {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub level: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tail: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub since: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub include_internal: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub filters: Option<BTreeMap<String, Value>>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct LogsUnsubscribeParams {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub subscription_id: Option<String>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
#[frb(unignore)]
pub struct LogEntry {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub timestamp: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ts: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub level: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub target: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub fields: Option<BTreeMap<String, Value>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub span: Option<Value>,
    #[serde(default)]
    pub spans: Vec<Value>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub thread_id: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub thread_name: Option<String>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
#[frb(unignore)]
pub struct LogsEvent {
    #[serde(default)]
    pub entries: Vec<LogEntry>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub entry: Option<LogEntry>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub subscription_id: Option<String>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct SystemProbeParams {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub network: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub disk: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub gateway: Option<bool>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct SystemProbeCheck {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ok: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub latency_ms: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub details: Option<Value>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct SystemProbeResult {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub network: Option<SystemProbeCheck>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub disk: Option<SystemProbeCheck>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub gateway: Option<SystemProbeCheck>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(tag = "type", content = "data", rename_all = "camelCase")]
#[frb(unignore)]
pub enum MediaEvent {
    CameraSnapshot(CameraSnapshot),
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct GatewayError {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub code: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub details: Option<Value>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub retryable: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub retry_after_ms: Option<u64>,
    #[serde(flatten, default)]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(untagged)]
pub enum GatewayRequestParams {
    AgentTurn(AgentTurn),
    SystemEvent(SystemEvent),
    Connect(ConnectParams),
    CameraSnapshot(CameraSnapshot),
    SessionsList(SessionsListParams),
    SessionsSpawn(SessionsSpawnParams),
    SessionsClose(SessionsCloseParams),
    StreamOpen(StreamOpenParams),
    StreamSend(StreamSendParams),
    StreamClose(StreamCloseParams),
    Exec(ExecParams),
    LogsSubscribe(LogsSubscribeParams),
    LogsUnsubscribe(LogsUnsubscribeParams),
    SystemProbe(SystemProbeParams),
    Unknown(Value),
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(untagged)]
pub enum GatewayResponsePayload {
    HelloOk(HelloOk),
    ExecResult(ExecOutput),
    SystemProbe(SystemProbeResult),
    Unknown(Value),
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[serde(untagged)]
#[frb(unignore)]
pub enum GatewayEventPayload {
    ConnectChallenge(ConnectChallenge),
    Presence(PresenceEvent),
    Shutdown(ShutdownEvent),
    Media(MediaEvent),
    ExecOutput(ExecOutput),
    Logs(LogsEvent),
    StreamData(StreamDataEvent),
    StreamClosed(StreamClosedEvent),
    Unknown(Value),
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "type", content = "data")]
#[frb(unignore)]
pub enum GatewayEvent {
    Connected,
    Disconnected { reason: String },
    Message { message: String },
    Error { message: String },
    Binary { data: Vec<u8> },
    ProtocolRequest {
        id: String,
        method: String,
        params: GatewayRequestParams,
        session_key: String,
    },
    ProtocolResponse {
        id: String,
        ok: bool,
        payload: GatewayResponsePayload,
        error: GatewayError,
        session_key: String,
    },
    ProtocolEvent {
        event: String,
        payload: GatewayEventPayload,
        seq: String,
        state_version: String,
        session_key: String,
    },
}

pub fn parse_gateway_frame(text: &str) -> Option<GatewayEvent> {
    let value: Value = serde_json::from_str(text).ok()?;
    let obj = value.as_object()?;
    let frame_type = obj.get("type")?.as_str()?;

    match frame_type {
        "req" => {
            let id = obj.get("id")?.as_str()?.to_string();
            let method = obj.get("method")?.as_str()?.to_string();
            let params_value = obj.get("params").cloned().unwrap_or(Value::Null);
            let params = parse_request_params(&method, params_value);
            let session_key = scalar_field(obj, "sessionKey");
            Some(GatewayEvent::ProtocolRequest {
                id,
                method,
                params,
                session_key,
            })
        }
        "res" => {
            let id = obj.get("id")?.as_str()?.to_string();
            let ok = obj.get("ok")?.as_bool()?;
            let payload_value = obj.get("payload").cloned().unwrap_or(Value::Null);
            let error_value = obj.get("error").cloned().unwrap_or(Value::Null);
            let payload = parse_response_payload(payload_value);
            let error = parse_error_payload(error_value);
            let session_key = scalar_field(obj, "sessionKey");
            Some(GatewayEvent::ProtocolResponse {
                id,
                ok,
                payload,
                error,
                session_key,
            })
        }
        "event" => {
            let event = obj.get("event")?.as_str()?.to_string();
            let payload_value = obj.get("payload").cloned().unwrap_or(Value::Null);
            let payload = parse_event_payload(&event, payload_value);
            let seq = scalar_field(obj, "seq");
            let state_version = scalar_field(obj, "stateVersion");
            let session_key = scalar_field(obj, "sessionKey");
            Some(GatewayEvent::ProtocolEvent {
                event,
                payload,
                seq,
                state_version,
                session_key,
            })
        }
        _ => None,
    }
}

fn parse_request_params(method: &str, value: Value) -> GatewayRequestParams {
    match method {
        "agent" => parse_payload::<AgentTurn>(value).map_or_else(
            |value| GatewayRequestParams::Unknown(value),
            GatewayRequestParams::AgentTurn,
        ),
        "system-event" => parse_payload::<SystemEvent>(value).map_or_else(
            |value| GatewayRequestParams::Unknown(value),
            GatewayRequestParams::SystemEvent,
        ),
        "connect" => parse_payload::<ConnectParams>(value).map_or_else(
            |value| GatewayRequestParams::Unknown(value),
            GatewayRequestParams::Connect,
        ),
        "camera_snap" => parse_payload::<CameraSnapshot>(value).map_or_else(
            |value| GatewayRequestParams::Unknown(value),
            GatewayRequestParams::CameraSnapshot,
        ),
        "sessions.list" => parse_payload::<SessionsListParams>(value).map_or_else(
            |value| GatewayRequestParams::Unknown(value),
            GatewayRequestParams::SessionsList,
        ),
        "sessions.spawn" => parse_payload::<SessionsSpawnParams>(value).map_or_else(
            |value| GatewayRequestParams::Unknown(value),
            GatewayRequestParams::SessionsSpawn,
        ),
        "sessions.close" => parse_payload::<SessionsCloseParams>(value).map_or_else(
            |value| GatewayRequestParams::Unknown(value),
            GatewayRequestParams::SessionsClose,
        ),
        "streams.open" | "stream.open" => parse_payload::<StreamOpenParams>(value).map_or_else(
            |value| GatewayRequestParams::Unknown(value),
            GatewayRequestParams::StreamOpen,
        ),
        "streams.send" | "stream.send" => parse_payload::<StreamSendParams>(value).map_or_else(
            |value| GatewayRequestParams::Unknown(value),
            GatewayRequestParams::StreamSend,
        ),
        "streams.close" | "stream.close" => parse_payload::<StreamCloseParams>(value).map_or_else(
            |value| GatewayRequestParams::Unknown(value),
            GatewayRequestParams::StreamClose,
        ),
        "exec" => parse_payload::<ExecParams>(value).map_or_else(
            |value| GatewayRequestParams::Unknown(value),
            GatewayRequestParams::Exec,
        ),
        "logs.subscribe" | "logs_subscribe" => parse_payload::<LogsSubscribeParams>(value)
            .map_or_else(
                |value| GatewayRequestParams::Unknown(value),
                GatewayRequestParams::LogsSubscribe,
            ),
        "logs.unsubscribe" | "logs_unsubscribe" => parse_payload::<LogsUnsubscribeParams>(value)
            .map_or_else(
                |value| GatewayRequestParams::Unknown(value),
                GatewayRequestParams::LogsUnsubscribe,
            ),
        "system.probe" | "system_probe" => parse_payload::<SystemProbeParams>(value).map_or_else(
            |value| GatewayRequestParams::Unknown(value),
            GatewayRequestParams::SystemProbe,
        ),
        _ => GatewayRequestParams::Unknown(value),
    }
}

fn parse_response_payload(value: Value) -> GatewayResponsePayload {
    let payload_type = value
        .get("type")
        .and_then(|value| value.as_str())
        .unwrap_or_default();
    if payload_type == "hello-ok" {
        if let Ok(payload) = serde_json::from_value::<HelloOk>(value.clone()) {
            return GatewayResponsePayload::HelloOk(payload);
        }
    }
    if payload_type == "exec-result" {
        if let Ok(payload) = serde_json::from_value::<ExecOutput>(value.clone()) {
            return GatewayResponsePayload::ExecResult(payload);
        }
    }
    if payload_type == "system-probe" {
        if let Ok(payload) = serde_json::from_value::<SystemProbeResult>(value.clone()) {
            return GatewayResponsePayload::SystemProbe(payload);
        }
    }
    GatewayResponsePayload::Unknown(value)
}

fn parse_error_payload(value: Value) -> GatewayError {
    serde_json::from_value(value).unwrap_or_default()
}

fn parse_event_payload(event: &str, value: Value) -> GatewayEventPayload {
    match event {
        "connect.challenge" => parse_payload::<ConnectChallenge>(value).map_or_else(
            |value| GatewayEventPayload::Unknown(value),
            GatewayEventPayload::ConnectChallenge,
        ),
        "presence" => parse_payload::<PresenceEvent>(value).map_or_else(
            |value| GatewayEventPayload::Unknown(value),
            GatewayEventPayload::Presence,
        ),
        "shutdown" => parse_payload::<ShutdownEvent>(value).map_or_else(
            |value| GatewayEventPayload::Unknown(value),
            GatewayEventPayload::Shutdown,
        ),
        "media" => parse_payload::<MediaEvent>(value).map_or_else(
            |value| GatewayEventPayload::Unknown(value),
            GatewayEventPayload::Media,
        ),
        "exec.output" | "exec.stream" => parse_payload::<ExecOutput>(value).map_or_else(
            |value| GatewayEventPayload::Unknown(value),
            GatewayEventPayload::ExecOutput,
        ),
        "logs" | "logs.entry" | "logs.entries" => parse_payload::<LogsEvent>(value).map_or_else(
            |value| GatewayEventPayload::Unknown(value),
            GatewayEventPayload::Logs,
        ),
        "stream.data" | "streams.data" => parse_payload::<StreamDataEvent>(value).map_or_else(
            |value| GatewayEventPayload::Unknown(value),
            GatewayEventPayload::StreamData,
        ),
        "stream.closed" | "streams.closed" => parse_payload::<StreamClosedEvent>(value)
            .map_or_else(
                |value| GatewayEventPayload::Unknown(value),
                GatewayEventPayload::StreamClosed,
            ),
        _ => GatewayEventPayload::Unknown(value),
    }
}

fn parse_payload<T: DeserializeOwned>(value: Value) -> Result<T, Value> {
    serde_json::from_value(value.clone()).map_err(|_| value)
}

fn scalar_field(obj: &serde_json::Map<String, Value>, key: &str) -> String {
    let value = match obj.get(key) {
        Some(value) => value,
        None => return String::new(),
    };

    if let Some(text) = value.as_str() {
        return text.to_string();
    }
    if let Some(number) = value.as_i64() {
        return number.to_string();
    }
    if let Some(number) = value.as_u64() {
        return number.to_string();
    }

    value.to_string()
}


impl SseEncode for GatewayResponsePayload {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        let json = serde_json::to_string(&self).unwrap_or_default();
        <String as SseEncode>::sse_encode(json, serializer);
    }
}

impl SseDecode for GatewayResponsePayload {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let json = <String as SseDecode>::sse_decode(deserializer);
        serde_json::from_str(&json).unwrap_or(GatewayResponsePayload::Unknown(Value::Null))
    }
}


impl flutter_rust_bridge::IntoDart for GatewayRequestParams {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        let json = serde_json::to_string(&self).unwrap_or_default();
        flutter_rust_bridge::IntoDart::into_dart(json)
    }
}

impl flutter_rust_bridge::IntoDart for GatewayResponsePayload {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        let json = serde_json::to_string(&self).unwrap_or_default();
        flutter_rust_bridge::IntoDart::into_dart(json)
    }
}

impl flutter_rust_bridge::IntoDart for GatewayEventPayload {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        let json = serde_json::to_string(&self).unwrap_or_default();
        flutter_rust_bridge::IntoDart::into_dart(json)
    }
}

impl flutter_rust_bridge::IntoDart for GatewayError {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        let json = serde_json::to_string(&self).unwrap_or_default();
        flutter_rust_bridge::IntoDart::into_dart(json)
    }
}

impl flutter_rust_bridge::IntoIntoDart<GatewayRequestParams> for GatewayRequestParams {
    fn into_into_dart(self) -> GatewayRequestParams {
        self
    }
}

impl flutter_rust_bridge::IntoIntoDart<GatewayResponsePayload> for GatewayResponsePayload {
    fn into_into_dart(self) -> GatewayResponsePayload {
        self
    }
}

impl flutter_rust_bridge::IntoIntoDart<GatewayEventPayload> for GatewayEventPayload {
    fn into_into_dart(self) -> GatewayEventPayload {
        self
    }
}

impl flutter_rust_bridge::IntoIntoDart<GatewayError> for GatewayError {
    fn into_into_dart(self) -> GatewayError {
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;

    #[test]
    fn parses_agent_turn_request() {
        let text = r#"{
            "type": "req",
            "id": "req-1",
            "method": "agent",
            "params": {
                "message": "Hello",
                "model": "gpt-5",
                "thinking": "medium",
                "timeoutSeconds": 42
            }
        }"#;

        let parsed = parse_gateway_frame(text).expect("frame should parse");
        match parsed {
            GatewayEvent::ProtocolRequest {
                params,
                session_key,
                ..
            } => {
                assert!(session_key.is_empty());
                assert_eq!(
                    params,
                    GatewayRequestParams::AgentTurn(AgentTurn {
                        message: "Hello".to_string(),
                        model: Some("gpt-5".to_string()),
                        thinking: Some("medium".to_string()),
                        timeout_seconds: Some(42),
                        extra: BTreeMap::new(),
                    })
                );
            }
            _ => panic!("expected protocol request"),
        }
    }

    #[test]
    fn parses_camera_snap_request() {
        let text = r#"{
            "type": "req",
            "id": "req-9",
            "method": "camera_snap",
            "params": {
                "data": "aGVsbG8=",
                "encoding": "base64",
                "format": "jpeg",
                "width": 640,
                "height": 480,
                "timestampMs": 123456
            }
        }"#;

        let parsed = parse_gateway_frame(text).expect("frame should parse");
        match parsed {
            GatewayEvent::ProtocolRequest { params, .. } => {
                assert_eq!(
                    params,
                    GatewayRequestParams::CameraSnapshot(CameraSnapshot {
                        data: "aGVsbG8=".to_string(),
                        encoding: "base64".to_string(),
                        compression: None,
                        format: Some("jpeg".to_string()),
                        width: Some(640),
                        height: Some(480),
                        timestamp_ms: Some(123456),
                        extra: BTreeMap::new(),
                    })
                );
            }
            _ => panic!("expected protocol request"),
        }
    }

    #[test]
    fn parses_exec_request() {
        let text = r#"{
            "type": "req",
            "id": "req-42",
            "method": "exec",
            "params": {
                "command": "ls",
                "args": ["-la", "/tmp"],
                "cwd": "/",
                "timeoutMs": 1200,
                "stream": true
            }
        }"#;

        let parsed = parse_gateway_frame(text).expect("frame should parse");
        match parsed {
            GatewayEvent::ProtocolRequest { params, .. } => {
                assert_eq!(
                    params,
                    GatewayRequestParams::Exec(ExecParams {
                        command: "ls".to_string(),
                        args: vec!["-la".to_string(), "/tmp".to_string()],
                        cwd: Some("/".to_string()),
                        env: None,
                        stdin: None,
                        timeout_ms: Some(1200),
                        stream: Some(true),
                        exec_id: None,
                        kill_on_drop: None,
                        extra: BTreeMap::new(),
                    })
                );
            }
            _ => panic!("expected protocol request"),
        }
    }

    #[test]
    fn parses_exec_output_event() {
        let text = r#"{
            "type": "event",
            "event": "exec.output",
            "seq": 1,
            "stateVersion": 2,
            "payload": {
                "execId": "exec-1",
                "stream": "stdout",
                "data": "hello",
                "encoding": "utf8",
                "eof": true,
                "exitCode": 0
            }
        }"#;

        let parsed = parse_gateway_frame(text).expect("frame should parse");
        match parsed {
            GatewayEvent::ProtocolEvent { payload, .. } => {
                assert_eq!(
                    payload,
                    GatewayEventPayload::ExecOutput(ExecOutput {
                        exec_id: Some("exec-1".to_string()),
                        stream: Some("stdout".to_string()),
                        data: Some("hello".to_string()),
                        encoding: Some("utf8".to_string()),
                        eof: Some(true),
                        exit_code: Some(0),
                        timestamp_ms: None,
                        extra: BTreeMap::new(),
                    })
                );
            }
            _ => panic!("expected protocol event"),
        }
    }

    #[test]
    fn parses_logs_event() {
        let text = r#"{
            "type": "event",
            "event": "logs",
            "seq": 9,
            "stateVersion": 9,
            "payload": {
                "entries": [{
                    "timestamp": "2025-01-01T00:00:00Z",
                    "level": "INFO",
                    "message": "booted",
                    "target": "gateway",
                    "fields": {
                        "session": "abc123"
                    },
                    "threadId": 7
                }]
            }
        }"#;

        let mut fields = BTreeMap::new();
        fields.insert("session".to_string(), Value::String("abc123".to_string()));

        let parsed = parse_gateway_frame(text).expect("frame should parse");
        match parsed {
            GatewayEvent::ProtocolEvent { payload, .. } => {
                assert_eq!(
                    payload,
                    GatewayEventPayload::Logs(LogsEvent {
                        entries: vec![LogEntry {
                            timestamp: Some("2025-01-01T00:00:00Z".to_string()),
                            ts: None,
                            level: Some("INFO".to_string()),
                            message: Some("booted".to_string()),
                            target: Some("gateway".to_string()),
                            fields: Some(fields),
                            span: None,
                            spans: Vec::new(),
                            thread_id: Some(7),
                            thread_name: None,
                            extra: BTreeMap::new(),
                        }],
                        entry: None,
                        subscription_id: None,
                        extra: BTreeMap::new(),
                    })
                );
            }
            _ => panic!("expected protocol event"),
        }
    }
}
