# LLWeb — Lum Lisp Web Framework

LLWeb is an MVC web framework for **Lum Lisp**. It provides routing, controllers, templates, ORM, schema migrations, WebSocket support, middleware pipeline, and code generators.

## Quick Start

```sh
# Scaffold a new project
ll ll_modules/lumlisp/web/init.ll myapp
cd myapp

# Run
ll web serve                # production
ll web serve dev            # dev with hot-reload

# Migrations
ll web migrate up           # apply pending migrations

# Generators
ll web generate controller posts index show create
ll web generate model post title:string body:text
```

---

## CLI Reference

```sh
ll web serve                    # Start HTTP server
ll web serve dev                # Dev server with hot-reload
ll web migrate up               # Apply pending migrations
ll web migrate down [n]         # Rollback n migrations
ll web migrate status           # Show migration status
ll web migrate rollback [n]     # Alias for down
ll web migrate reset            # Rollback all migrations
ll web migrate fresh            # Drop all tables + re-migrate
ll web generate controller <name> [actions...]
ll web generate model <name> [field:type:opts...]
```

---

## Configuration (`.env`)

| Key | Default | Description |
|-----|---------|-------------|
| `HOST` | `localhost` | Server bind address |
| `PORT` | `8000` | Server port |
| `DB` | `storage/llweb.db` | SQLite database path |
| `STATIC_DIR` | `static` | Static files directory |
| `VIEW_DIR` | `app/Views` | Template directory |
| `LAYOUT` | `layout` | Layout template name (without `.html`) |

---

## Project Structure

```
.env                  # Configuration
web                   # CLI entry point
app/
  Controllers/        # *.ll — controllers
  Models/             # *.ll — models
  Views/              # *.html — templates
  Routes.ll           # imports all controllers
  Migrations.ll       # migration definitions
  client/             # *.ll — client-side (transpiled to JS)
storage/              # SQLite database
static/               # Static assets (CSS, JS, images)
ll_modules/lumlisp/web/  # Framework source
```

---

## Routing

```scheme
; app/Controllers/Posts.ll
(import "lumlisp/web/View")

(defclass PostController (Controller) ())

(router/add-route "GET" "/posts" PostController 'index)
(router/add-route "GET" "/posts/:id" PostController 'show)
(router/add-route "POST" "/posts" PostController 'create)

(defmethod PostController index (self ctx)
  (define req (car ctx))
  (define params (cadr ctx))
  (return (View/render "Posts" (list
    (cons "title" "All Posts")))))

(defmethod PostController show (self ctx)
  (define params (cadr ctx))
  (define id (cdr (assoc "id" params)))  ; from :id in route
  ...)
```

Route patterns support `:param` segments. Extracted params are passed as an alist in the `params` controller slot.

### Route aggregator

```scheme
; app/Routes.ll
(import "Controllers/Index")
(import "Controllers/Posts")
```

---

## Middleware

```scheme
; Request logger
(middleware/add (lambda (req next)
  (println "[mw] " (http/request-method req) " " (http/request-path req))
  (next req)))

; CSRF protection
(middleware/add (lambda (req next)
  (define method (http/request-method req))
  (if (string=? method "POST")
    (begin
      (define body (http/request-body req))
      (if (not (string-find body "_csrf"))
        (http/make-response 403 '() "CSRF token required")
        (next req)))
    (next req))))
```

Middleware executes in registration order. Each function receives `(req next)` — `req` is the request object, `next` passes control to the next middleware.

---

## Controllers

### Slots

| Slot | Description |
|------|-------------|
| `req` | Raw HTTP request object |
| `params` | Route parameters (alist) |
| `method` | HTTP method string |
| `path` | Request path |
| `view-data` | View data storage |

### Responses

```scheme
; HTML
(return (View/render "view-name" data))

; HTML with custom status
(return (render-status 201 "Created" data))

; JSON
(return (render-json (list (cons "status" "ok"))))

; JSON with custom status
(return (render-json-status 201 (list (cons "id" 1))))

; Redirect
(return (redirect "/posts"))
(return (redirect-back))
```

### Request Body Parsing

```scheme
(defmethod PostController create (self ctx)
  ; Parse JSON body → alist
  (define data (json-body))

  ; Parse form-encoded body → alist
  (define form (form-body))

  ; Parse query string → alist
  (define qs (query-params))
  ...)
```

### CSRF Protection

```scheme
; In templates:
; {{csrf-field}}  ← <input type="hidden" name="_csrf" value="...">
; {{csrf-meta}}   ← <meta name="csrf-token" content="...">

; In controllers:
(define token (csrf/generate-token))
(csrf/validate-token token)  ; returns #t or #f
```

### Flash Messages

```scheme
(flash/set "success" "Post created!")
(flash/get "success")          ; "Post created!" (consumed on read)
(flash/has? "success")         ; #t or #f
```

---

## Templates

Views live in `app/Views/*.html`. Variables use `{{name}}` syntax.

```html
<!-- app/Views/layout.html -->
<!DOCTYPE html>
<html>
<head><title>{{title}}</title></head>
<body>
  <div class="flash">{{flash}}</div>
  {{content}}
</body>
</html>
```

```html
<!-- app/Views/Posts.html -->
<h1>{{title}}</h1>
<p>{{message}}</p>
@code("main.ll")  <!-- LL → JS transpilation -->
```

The `@code("file.ll")` directive transpiles Lum Lisp from `app/client/` to JavaScript at runtime.

---

## WebSocket

```scheme
(router/add-ws-route "/chat" (lambda (req params)
  (define conn (ws/connect "ws://localhost:8000/ws/chat"))
  (ws/send conn "hello")
  (println (ws/receive conn))
  (ws/close conn)))
```

WebSocket routes are registered via `router/add-ws-route` and are accessible at `/ws/*`.

---

## Migrations

```scheme
; app/Migrations.ll
(Migration/register "001_create_posts"
  (lambda ()
    (schema/create-table "posts" (list
      (list 'id 'integer 'primary 'autoinc)
      (list 'title 'string)
      (list 'body 'text)
      (list 'user_id 'integer 'index)
      (list 'created_at 'timestamp 'default "CURRENT_TIMESTAMP"))))
  (lambda ()
    (schema/drop-table "posts")))
```

### Schema DSL

```scheme
(schema/create-table "name" columns)
(schema/drop-table "name")
(schema/add-column "table" col)
(schema/drop-column "table" "col-name")
(schema/rename-table "old" "new")
(schema/create-index "table" '("col1" "col2") "idx_name")
(schema/drop-index "idx_name")
```

**Column types:** `integer`, `bigint`, `string`, `text`, `boolean`, `float`, `decimal`, `timestamp`, `datetime`, `blob`

**Column options:** `primary`, `autoinc`, `nullable`, `unique`, `index`, `unsigned`, `default VALUE`

### CLI

```sh
ll web migrate up              # Apply pending
ll web migrate down            # Rollback last
ll web migrate down 3          # Rollback 3
ll web migrate reset           # Rollback all
ll web migrate fresh           # Drop all, then re-migrate
ll web migrate status          # Show all with status
```

---

## Models (ORM)

**Parameterized queries** protect against SQL injection. Fluent query builder and relationship support.

### Setup

```scheme
(define posts (Model/new "posts" '(id title body user_id created_at)))
```

### Querying

```scheme
; All records
(send posts 'all)

; Sorted
(send posts 'order "created_at DESC" 'all)

; Limited
(send posts 'limit 10 'all)

; Paginated
(send posts 'limit 10 'offset 20 'all)

; Find by ID
(send posts 'find 1)

; Filter
(send posts 'where (list (cons "user_id" "5")))

; Filter + sort + limit
(send posts 'where (list (cons "user_id" "5"))
              'order "created_at DESC"
              'limit 5
              'all)

; Count
(send posts 'count)
```

### Create / Update / Delete

```scheme
; Create
(send posts 'create (list
  (cons "title" "Hello")
  (cons "body" "World")))

; Read field
(define p (send posts 'find 1))
(send p 'get "title")          ; "Hello"

; Update single field
(send p 'set (list "title" "Updated"))

; Bulk update
(send p 'update (list
  (cons "title" "New")
  (cons "body" "Content")))

; Delete
(send p 'delete)

; Reload from DB
(send p 'reload)
```

### Relationships

```scheme
; has-many: post has many comments
(define p (send posts 'find 1))
(send p 'has-many "comments" "post_id")

; belongs-to: comment belongs to a post
(define c (send comments 'find 1))
(send c 'belongs-to "posts" "post_id")
```

### Functional API (backward compatible)

```scheme
(model-all posts)
(model-find posts 1)
(model-create posts data)
(model-update posts 1 data)
(model-delete posts 1)
(model-where posts filters)
(model-count posts)
```

---

## Error Handling

```scheme
; Custom 404 page
(llweb/set-not-found-handler (lambda ()
  (http/make-response 404
    (list (cons "Content-Type" "text/html"))
    "<h1>404 — Not Found</h1>")))

; Custom 500 handler
(llweb/set-error-handler (lambda (status msg)
  (http/make-response status
    (list (cons "Content-Type" "application/json"))
    (json/encode (list (cons "error" msg) (cons "status" status))))))
```

---

## Static Files

Files in `static/` are served automatically:

```
static/css/app.css  →  GET /css/app.css
static/js/main.js   →  GET /js/main.js
static/img/logo.png →  GET /img/logo.png
```

Supported MIME types: CSS, JS, WASM, PNG, JPG, WebP, GIF, SVG, ICO, JSON, HTML, TXT, PDF, WOFF2, TTF, OTF.

---

## Client-Side Code

LL → JS transpilation. Files in `app/client/` are served at `/c/` and automatically compiled to JavaScript.

```scheme
; app/client/main.ll
(define (init)
  (dom/set-text! (dom/q "h1") "Hello from LL!"))
(init)
```

In templates:
```html
@code("main.ll")
```

Supported in JS target: `define`, `lambda`, `if`, `cond`, `while`, `for`, `future`/`await`/`co`, DOM operations (`dom/q`, `dom/id`, `dom/on`, `dom/css`), JSON, OOP.

---

## What's New (v2.0)

- **Parameterized queries** — SQL injection protection in Model.ll
- **Query builder** — `order`, `limit`, `offset`, fluent API
- **Relationships** — `has-many`, `belongs-to`
- **Middleware pipeline** — request processing chain
- **WebSocket** — `router/add-ws-route` integration
- **Request body parsing** — `json-body`, `form-body`, `query-params`
- **CSRF protection** — token generation + validation
- **Flash messages** — one-time notifications
- **Indexes** — `index` column option, `schema/create-index`
- **`migrate fresh` / `migrate reset`** — full DB reset commands
- **Generators** — `generate controller`, `generate model`
- **Custom error pages** — `set-error-handler`, `set-not-found-handler`
- **New MIME types** — WebP, WASM, WOFF2, TTF, OTF for static files
- **Extended schema** — `bigint`, `blob`, `datetime`, `unsigned` column types
