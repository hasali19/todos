use std::str::FromStr;

use eyre::WrapErr;
use sqlx::sqlite::{SqliteConnectOptions, SqlitePool, SqlitePoolOptions};

use crate::models::{CreateTask, Task, TaskStatus, UpdateTask};

pub async fn connect(url: &str) -> eyre::Result<SqlitePool> {
    let options = SqliteConnectOptions::from_str(url)
        .wrap_err_with(|| format!("invalid database url {url:?}"))?
        .create_if_missing(true);

    let pool = SqlitePoolOptions::new()
        .connect_with(options)
        .await
        .wrap_err_with(|| format!("failed to open database {url:?}"))?;

    sqlx::migrate!()
        .run(&pool)
        .await
        .wrap_err("failed to run database migrations")?;

    Ok(pool)
}

pub async fn get_tasks(pool: &SqlitePool) -> sqlx::Result<Vec<Task>> {
    sqlx::query_as::<_, Task>(
        "SELECT id, title, description, status, inserted_at FROM tasks ORDER BY id",
    )
    .fetch_all(pool)
    .await
}

pub async fn create_task(pool: &SqlitePool, input: CreateTask) -> sqlx::Result<Task> {
    sqlx::query_as::<_, Task>(
        "INSERT INTO tasks (title, description, status) VALUES (?, ?, ?)
         RETURNING id, title, description, status, inserted_at",
    )
    .bind(input.title)
    .bind(input.description)
    .bind(input.status.unwrap_or(TaskStatus::Todo))
    .fetch_one(pool)
    .await
}

pub async fn update_task(
    pool: &SqlitePool,
    id: i64,
    input: UpdateTask,
) -> sqlx::Result<Option<Task>> {
    sqlx::query_as::<_, Task>(
        "UPDATE tasks SET
             title       = COALESCE(?, title),
             description = COALESCE(?, description),
             status      = COALESCE(?, status)
         WHERE id = ?
         RETURNING id, title, description, status, inserted_at",
    )
    .bind(input.title)
    .bind(input.description)
    .bind(input.status)
    .bind(id)
    .fetch_optional(pool)
    .await
}
