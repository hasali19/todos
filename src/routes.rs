use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    routing::{get, patch},
};
use sqlx::SqlitePool;
use std::path::Path as FsPath;
use tower_http::services::{ServeDir, ServeFile};

use crate::db;
use crate::error::ApiError;
use crate::models::{CreateTask, Task, UpdateTask};

pub fn app_router(pool: SqlitePool, static_dir: Option<&FsPath>) -> Router {
    let app = Router::new().nest("/api", api_router(pool));
    match static_dir {
        None => app,
        Some(dir) => app
            .fallback_service(ServeDir::new(dir).fallback(ServeFile::new(dir.join("index.html")))),
    }
}

pub fn api_router(pool: SqlitePool) -> Router {
    Router::new()
        .route("/tasks", get(list_tasks).post(create_task))
        .route("/tasks/{id}", patch(update_task))
        .with_state(pool)
        .fallback(|| async { StatusCode::NOT_FOUND })
}

async fn list_tasks(State(pool): State<SqlitePool>) -> Result<Json<Vec<Task>>, ApiError> {
    Ok(Json(db::get_tasks(&pool).await?))
}

async fn create_task(
    State(pool): State<SqlitePool>,
    Json(input): Json<CreateTask>,
) -> Result<(StatusCode, Json<Task>), ApiError> {
    validate_title(&input.title)?;
    let task = db::create_task(&pool, input).await?;
    Ok((StatusCode::CREATED, Json(task)))
}

async fn update_task(
    State(pool): State<SqlitePool>,
    Path(id): Path<i64>,
    Json(input): Json<UpdateTask>,
) -> Result<Json<Task>, ApiError> {
    if let Some(title) = &input.title {
        validate_title(title)?;
    }

    let task = db::update_task(&pool, id, input)
        .await?
        .ok_or(ApiError::NotFound)?;

    Ok(Json(task))
}

fn validate_title(title: &str) -> Result<(), ApiError> {
    if title.trim().is_empty() {
        return Err(ApiError::BadRequest("title must not be empty".into()));
    }
    Ok(())
}
