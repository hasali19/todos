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

    let pool = connect(&database_url).await?;
    let app = routes::router(pool);

    let listener = tokio::net::TcpListener::bind(&bind_addr)
        .await
        .wrap_err_with(|| format!("failed to bind {bind_addr}"))?;

    tracing::info!("listening on http://{bind_addr}");
    axum::serve(listener, app).await?;

    Ok(())
}
