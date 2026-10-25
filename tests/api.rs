use axum::{
    Router,
    body::Body,
    http::{Request, StatusCode},
};
use http_body_util::BodyExt;
use serde_json::{Value, json};
use tower::ServiceExt;

use todos::{connect, routes};

async fn app() -> Router {
    app_with_static(None).await
}

async fn app_with_static(static_dir: Option<&std::path::Path>) -> Router {
    // Each in-memory pool connection would get its own empty database,
    // so use a shared-cache in-memory DB with a unique name per test.
    let name = format!(
        "sqlite:file:test{}?mode=memory&cache=shared",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    );
    routes::app_router(connect(&name).await.unwrap(), static_dir)
}

async fn send(app: &Router, method: &str, uri: &str, body: Option<Value>) -> (StatusCode, Value) {
    let mut req = Request::builder().method(method).uri(uri);
    let body = match body {
        Some(b) => {
            req = req.header("content-type", "application/json");
            Body::from(b.to_string())
        }
        None => Body::empty(),
    };
    let res = app.clone().oneshot(req.body(body).unwrap()).await.unwrap();
    let status = res.status();
    let bytes = res.into_body().collect().await.unwrap().to_bytes();
    // Axum's own rejections (e.g. malformed JSON) reply with plain text.
    let json = serde_json::from_slice(&bytes)
        .unwrap_or_else(|_| Value::String(String::from_utf8_lossy(&bytes).into_owned()));
    (status, json)
}

#[tokio::test]
async fn create_list_update() {
    let app = app().await;

    let (status, body) = send(&app, "GET", "/api/tasks", None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body, json!([]));

    let (status, task) = send(
        &app,
        "POST",
        "/api/tasks",
        Some(json!({ "title": "Buy milk", "description": "2 litres" })),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED);
    assert_eq!(task["title"], "Buy milk");
    assert_eq!(task["description"], "2 litres");
    assert_eq!(task["status"], "todo");
    assert!(task["inserted_at"].is_string());
    let id = task["id"].as_i64().unwrap();

    let (status, updated) = send(
        &app,
        "PATCH",
        &format!("/api/tasks/{id}"),
        Some(json!({ "status": "in_progress" })),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(updated["status"], "in_progress");
    assert_eq!(updated["title"], "Buy milk");

    let (_, list) = send(&app, "GET", "/api/tasks", None).await;
    assert_eq!(list.as_array().unwrap().len(), 1);
    assert_eq!(list[0]["status"], "in_progress");
}

#[tokio::test]
async fn errors() {
    let app = app().await;

    let (status, _) = send(
        &app,
        "PATCH",
        "/api/tasks/999",
        Some(json!({ "title": "x" })),
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    let (status, _) = send(&app, "POST", "/api/tasks", Some(json!({ "title": "  " }))).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);

    let (status, _) = send(
        &app,
        "POST",
        "/api/tasks",
        Some(json!({ "title": "a", "status": "bogus" })),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
}

#[tokio::test]
async fn serves_web_app() {
    let dir = std::env::temp_dir().join(format!("todos-static-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    std::fs::write(dir.join("index.html"), "\"index\"").unwrap();
    std::fs::write(dir.join("main.js"), "\"js\"").unwrap();
    let app = app_with_static(Some(&dir)).await;

    assert_eq!(
        send(&app, "GET", "/", None).await,
        (StatusCode::OK, json!("index"))
    );
    assert_eq!(
        send(&app, "GET", "/main.js", None).await,
        (StatusCode::OK, json!("js"))
    );
    // Unknown paths fall back to index.html, except under /api.
    assert_eq!(
        send(&app, "GET", "/some/page", None).await,
        (StatusCode::OK, json!("index"))
    );
    assert_eq!(
        send(&app, "GET", "/api/nope", None).await.0,
        StatusCode::NOT_FOUND
    );
    assert_eq!(
        send(&app, "GET", "/api/tasks", None).await,
        (StatusCode::OK, json!([]))
    );

    std::fs::remove_dir_all(&dir).unwrap();
}

#[tokio::test]
async fn subtasks() {
    let app = app().await;

    let (_, parent) = send(&app, "POST", "/api/tasks", Some(json!({ "title": "Trip" }))).await;
    assert_eq!(parent["parent_id"], Value::Null);
    let parent_id = parent["id"].as_i64().unwrap();

    let (status, sub) = send(
        &app,
        "POST",
        "/api/tasks",
        Some(json!({ "title": "Book flights", "parent_id": parent_id })),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED);
    assert_eq!(sub["parent_id"], parent_id);

    // Subtasks can have their own subtasks.
    let (status, subsub) = send(
        &app,
        "POST",
        "/api/tasks",
        Some(json!({ "title": "Compare prices", "parent_id": sub["id"] })),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED);
    assert_eq!(subsub["parent_id"], sub["id"]);

    let (_, list) = send(&app, "GET", "/api/tasks", None).await;
    assert_eq!(list.as_array().unwrap().len(), 3);

    let (status, _) = send(
        &app,
        "POST",
        "/api/tasks",
        Some(json!({ "title": "Orphan", "parent_id": 999 })),
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
}
