import os

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("SECRET_KEY", "test-secret-key")

import pytest

from app import Post, app, db


@pytest.fixture(autouse=True)
def reset_database():
    app.config.update(TESTING=True)

    with app.app_context():
        db.drop_all()
        db.create_all()

    yield

    with app.app_context():
        db.session.remove()
        db.drop_all()


@pytest.fixture
def client():
    return app.test_client()


def test_index_returns_success(client):
    response = client.get("/")

    assert response.status_code == 200
    assert b"All Posts" in response.data


def test_create_page_returns_success(client):
    response = client.get("/create")

    assert response.status_code == 200
    assert b"Create New Post" in response.data


def test_empty_post_submission_shows_validation_message(client):
    response = client.post(
        "/create",
        data={"title": "", "content": ""},
        follow_redirects=True,
    )

    assert response.status_code == 200
    assert b"Title and content are required!" in response.data


def test_valid_post_creation_redirects_to_index(client):
    response = client.post(
        "/create",
        data={"title": "First test post", "content": "This came from pytest."},
        follow_redirects=True,
    )

    assert response.status_code == 200
    assert b"Post created successfully!" in response.data
    assert b"First test post" in response.data
    assert b"This came from pytest." in response.data


def test_view_existing_post_returns_success(client):
    with app.app_context():
        post = Post(title="Existing post", content="A post already in the database.")
        db.session.add(post)
        db.session.commit()
        post_id = post.id

    response = client.get(f"/post/{post_id}")

    assert response.status_code == 200
    assert b"Existing post" in response.data
    assert b"A post already in the database." in response.data
