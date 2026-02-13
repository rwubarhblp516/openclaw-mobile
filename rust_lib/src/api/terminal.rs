use crate::api::connection::GatewayClient;
use crate::api::events::{
    parse_gateway_frame, ExecOutput, GatewayEvent, GatewayEventPayload, GatewayResponsePayload,
};
use crate::frb_generated::StreamSink;
use anyhow::{anyhow, Result};
use base64::{engine::general_purpose::STANDARD, Engine as _};
use futures_util::{SinkExt, StreamExt};
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};

#[derive(Debug, Clone)]
pub struct TerminalChunk {
    pub text: String,
    pub kind: String,
}

pub async fn exec_command(
    url: String,
    command: String,
    cwd: Option<String>,
    timeout_ms: Option<u64>,
    session_key: Option<String>,
    sink: StreamSink<TerminalChunk>,
) -> Result<()> {
    let client = GatewayClient::new(url.clone());
    let request_id = client.next_request_id();

    let request_json = client.exec_request(
        request_id.clone(),
        "sh".to_string(),
        vec!["-lc".to_string(), command],
        cwd,
        None,
        None,
        timeout_ms,
        Some(true),
        None,
        Some(true),
        session_key,
    )?;

    let (ws_stream, _) = connect_async(&url).await?;
    let (mut write, mut read) = ws_stream.split();
    write.send(Message::Text(request_json.into())).await?;

    while let Some(message) = read.next().await {
        match message {
            Ok(Message::Text(text)) => {
                let Some(frame) = parse_gateway_frame(&text) else {
                    continue;
                };

                match frame {
                    GatewayEvent::ProtocolResponse {
                        id,
                        ok,
                        payload,
                        error,
                        ..
                    } => {
                        if id != request_id {
                            continue;
                        }
                        if !ok {
                            let message = error
                                .message
                                .unwrap_or_else(|| "exec request failed".to_string());
                            let _ = sink.add(TerminalChunk {
                                text: message.clone(),
                                kind: "error".to_string(),
                            });
                            return Err(anyhow!(message));
                        }

                        if let GatewayResponsePayload::ExecResult(output) = payload {
                            emit_exec_output(&sink, &output);
                            if output.exit_code.is_some() {
                                return Ok(());
                            }
                        }
                    }
                    GatewayEvent::ProtocolEvent { payload, .. } => {
                        if let GatewayEventPayload::ExecOutput(output) = payload {
                            emit_exec_output(&sink, &output);
                            if output.exit_code.is_some() {
                                return Ok(());
                            }
                        }
                    }
                    _ => {}
                }
            }
            Ok(Message::Close(_)) => break,
            Ok(_) => {}
            Err(error) => {
                let _ = sink.add(TerminalChunk {
                    text: error.to_string(),
                    kind: "error".to_string(),
                });
                return Err(error.into());
            }
        }
    }

    Ok(())
}

pub async fn terminal_stream_open(
    url: String,
    cols: Option<u32>,
    rows: Option<u32>,
    term: Option<String>,
    session_key: Option<String>,
) -> Result<String> {
    let client = GatewayClient::new(url.clone());
    let request_id = client.next_request_id();
    let request_json = client.interactive_shell_open_request(
        request_id.clone(),
        cols,
        rows,
        term,
        None,
        Some(r#"{"elevated":true}"#.to_string()),
        session_key,
    )?;

    let response = send_request_and_wait_response(url, request_id, request_json).await?;
    let GatewayResponsePayload::Unknown(payload) = response else {
        return Err(anyhow!("streams.open response payload was not recognized"));
    };

    payload
        .get("streamId")
        .and_then(|value| value.as_str())
        .map(|value| value.to_string())
        .ok_or_else(|| anyhow!("streams.open response missing streamId"))
}

pub async fn terminal_stream_send(
    url: String,
    stream_id: String,
    input_bytes: Vec<u8>,
    session_key: Option<String>,
) -> Result<()> {
    let client = GatewayClient::new(url.clone());
    let request_id = client.next_request_id();
    let request_json = client.interactive_shell_send_request(
        request_id.clone(),
        Some(stream_id),
        input_bytes,
        Some("stdin".to_string()),
        Some(r#"{"elevated":true}"#.to_string()),
        session_key,
    )?;

    let _ = send_request_and_wait_response(url, request_id, request_json).await?;
    Ok(())
}

async fn send_request_and_wait_response(
    url: String,
    request_id: String,
    request_json: String,
) -> Result<GatewayResponsePayload> {
    let (ws_stream, _) = connect_async(&url).await?;
    let (mut write, mut read) = ws_stream.split();
    write.send(Message::Text(request_json.into())).await?;

    while let Some(message) = read.next().await {
        match message {
            Ok(Message::Text(text)) => {
                let Some(frame) = parse_gateway_frame(&text) else {
                    continue;
                };

                if let GatewayEvent::ProtocolResponse {
                    id,
                    ok,
                    payload,
                    error,
                    ..
                } = frame
                {
                    if id != request_id {
                        continue;
                    }

                    if ok {
                        return Ok(payload);
                    }

                    let message = error
                        .message
                        .unwrap_or_else(|| "gateway request failed".to_string());
                    return Err(anyhow!(message));
                }
            }
            Ok(Message::Close(_)) => {
                return Err(anyhow!("connection closed before response"));
            }
            Ok(_) => {}
            Err(error) => return Err(error.into()),
        }
    }

    Err(anyhow!("connection closed before response"))
}

fn emit_exec_output(sink: &StreamSink<TerminalChunk>, output: &ExecOutput) {
    if let Some(data) = output.data.clone() {
        let decoded = decode_output_data(data, output.encoding.as_deref());
        if !decoded.is_empty() {
            let stream = output.stream.as_deref().unwrap_or("stdout");
            let kind = if stream == "stderr" { "error" } else { "output" };
            let _ = sink.add(TerminalChunk {
                text: decoded,
                kind: kind.to_string(),
            });
        }
    }

    if let Some(exit_code) = output.exit_code {
        let _ = sink.add(TerminalChunk {
            text: format!("Process exited with code {exit_code}."),
            kind: "system".to_string(),
        });
    }
}

fn decode_output_data(data: String, encoding: Option<&str>) -> String {
    match encoding {
        Some(value) if value.eq_ignore_ascii_case("base64") => STANDARD
            .decode(data.as_bytes())
            .map(|bytes| String::from_utf8_lossy(&bytes).to_string())
            .unwrap_or(data),
        _ => data,
    }
}
