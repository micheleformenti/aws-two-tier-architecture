from flask import Flask, render_template, request, redirect, url_for, flash
from flask_sqlalchemy import SQLAlchemy
from datetime import UTC, datetime
import os

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ.get(
    "SECRET_KEY",
    "dev-secret-key-change-in-production",  # Default value only used for local development
)

# Construct DATABASE_URL from environment variables if in container
db_host = os.environ.get("DB_HOST")
db_user = os.environ.get("DB_USER", "postgres")
db_password = os.environ.get("DB_PASSWORD")
db_name = os.environ.get("DB_NAME")

if db_host and db_password:
    database_url = f"postgresql://{db_user}:{db_password}@{db_host}:5432/{db_name}"
else:
    # Fallback for local development
    database_url = "postgresql://postgres:postgres@localhost:5432/flask_blog"

app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get("DATABASE_URL", database_url)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)


# Post Model
class Post(db.Model):
    __tablename__ = "posts"

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(UTC))

    def __repr__(self):
        return f"<Post {self.title}>"


# Create tables
with app.app_context():
    db.create_all()


# Routes
@app.route("/")
def index():
    posts = Post.query.order_by(Post.created_at.desc()).all()
    return render_template("index.html", posts=posts)


@app.route("/create", methods=["GET", "POST"])
def create_post():
    if request.method == "POST":
        title = request.form.get("title")
        content = request.form.get("content")

        if not title or not content:
            flash("Title and content are required!", "error")
            return redirect(url_for("create_post"))

        new_post = Post(title=title, content=content)
        db.session.add(new_post)
        db.session.commit()

        flash("Post created successfully!", "success")
        return redirect(url_for("index"))

    return render_template("create.html")


@app.route("/post/<int:post_id>")
def view_post(post_id):
    post = db.get_or_404(Post, post_id)
    return render_template("view_post.html", post=post)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
