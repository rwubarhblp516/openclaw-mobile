extern crate self as chrono;

pub mod api;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
pub use anyhow::Result;
pub use futures_util::future::BoxFuture;
pub use tokio_tungstenite::WebSocketStream;
pub type Stream = tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>;

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Duration {
    micros: i64,
}

impl Duration {
    pub fn microseconds(micros: i64) -> Self {
        Self { micros }
    }

    pub fn milliseconds(millis: i64) -> Self {
        Self {
            micros: millis.saturating_mul(1_000),
        }
    }

    pub fn seconds(secs: i64) -> Self {
        Self {
            micros: secs.saturating_mul(1_000_000),
        }
    }

    pub fn num_microseconds(&self) -> Option<i64> {
        Some(self.micros)
    }

    pub fn to_std(self) -> Result<std::time::Duration, ()> {
        if self.micros < 0 {
            return Err(());
        }
        Ok(std::time::Duration::from_micros(self.micros as u64))
    }
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default configuration for flutter_rust_bridge
    flutter_rust_bridge::setup_default_user_utils();
}
