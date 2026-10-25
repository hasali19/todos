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
    // Each in-memory pool connection would get its own empty database,
    // so use a shared-cache in-memory DB with a unique name per test.
    let name = format!(
        "sqlite:file:test{}?mode=memory&cache=shared",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    );
    routes::router(connect(&name).await.unwrap())
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

    let (status, body) = send(&app, "GET", "/tasks", None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body, json!([]));

    let (status, task) = send(
        &app,
        "POST",
        "/tasks",
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
        &format!("/tasks/{id}"),
        Some(json!({ "status": "in_progress" })),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(updated["status"], "in_progress");
    assert_eq!(updated["title"], "Buy milk");

    let (_, list) = send(&app, "GET", "/tasks", None).await;
    assert_eq!(list.as_array().unwrap().len(), 1);
    assert_eq!(list[0]["status"], "in_progress");
}

#[tokio::test]
async fn errors() {
    let app = app().await;

    let (status, _) = send(&app, "PATCH", "/tasks/999", Some(json!({ "title": "x" }))).await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    let (status, _) = send(&app, "POST", "/tasks", Some(json!({ "title": "  " }))).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);

    let (status, _) = send(
        &app,
        "POST",
        "/tasks",
        Some(json!({ "title": "a", "status": "bogus" })),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
}
