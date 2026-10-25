use std::str::FromStr;

use eyre::WrapErr;
use sqlx::sqlite::{SqliteConnectOptions, SqliteConnection, SqlitePool, SqlitePoolOptions};

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

pub async fn get_tasks(conn: &mut SqliteConnection) -> sqlx::Result<Vec<Task>> {
    sqlx::query_as::<_, Task>(
        "SELECT id, title, description, status, parent_id, inserted_at FROM tasks ORDER BY id",
    )
    .fetch_all(conn)
    .await
}

pub async fn get_task(conn: &mut SqliteConnection, id: i64) -> sqlx::Result<Option<Task>> {
    sqlx::query_as::<_, Task>(
        "SELECT id, title, description, status, parent_id, inserted_at FROM tasks WHERE id = ?",
    )
    .bind(id)
    .fetch_optional(conn)
    .await
}

pub async fn create_task(conn: &mut SqliteConnection, input: CreateTask) -> sqlx::Result<Task> {
    sqlx::query_as::<_, Task>(
        "INSERT INTO tasks (title, description, status, parent_id) VALUES (?, ?, ?, ?)
         RETURNING id, title, description, status, parent_id, inserted_at",
    )
    .bind(input.title)
    .bind(input.description)
    .bind(input.status.unwrap_or(TaskStatus::Todo))
    .bind(input.parent_id)
    .fetch_one(conn)
    .await
}

pub async fn update_task(
    conn: &mut SqliteConnection,
    id: i64,
    input: UpdateTask,
) -> sqlx::Result<Option<Task>> {
    sqlx::query_as::<_, Task>(
        "UPDATE tasks SET
             title       = COALESCE(?, title),
             description = COALESCE(?, description),
             status      = COALESCE(?, status)
         WHERE id = ?
         RETURNING id, title, description, status, parent_id, inserted_at",
    )
    .bind(input.title)
    .bind(input.description)
    .bind(input.status)
    .bind(id)
    .fetch_optional(conn)
    .await
}
