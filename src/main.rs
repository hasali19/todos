use std::path::PathBuf;

use eyre::WrapErr;
use tracing_subscriber::EnvFilter;

use todos::{connect, routes};

#[tokio::main]
async fn main() -> eyre::Result<()> {
    color_eyre::install()?;

    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::from("info")),
        )
        .init();

    let database_url =
        std::env::var("DATABASE_URL").unwrap_or_else(|_| "sqlite://todos.db".to_string());
    let bind_addr = std::env::var("BIND_ADDR").unwrap_or_else(|_| "127.0.0.1:3000".to_string());
    let static_dir = std::env::var_os("STATIC_DIR").map(PathBuf::from);

    let pool = connect(&database_url).await?;
    let app = routes::app_router(pool, static_dir.as_deref());

    if let Some(dir) = &static_dir {
        tracing::info!("serving static files from {}", dir.display());
    }

    let listener = tokio::net::TcpListener::bind(&bind_addr)
        .await
        .wrap_err_with(|| format!("failed to bind {bind_addr}"))?;

    tracing::info!("listening on http://{bind_addr}");
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c().await.ok();
    };

    #[cfg(unix)]
    let terminate = async {
        use tokio::signal::unix::{SignalKind, signal};
        match signal(SignalKind::terminate()) {
            Ok(mut sig) => {
                sig.recv().await;
            }
            Err(_) => std::future::pending().await,
        }
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        () = ctrl_c => {},
        () = terminate => {},
    }

    tracing::info!("shutting down");
}
