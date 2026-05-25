# LLWeb — Lum Lisp Web Framework

## CLI Usage

```sh
ll web.ll serve              # Start production server
ll web.ll serve dev          # Start dev server with hot reload
ll web.ll migrate up         # Run pending migrations
ll web.ll migrate down [n]   # Rollback last n migrations
ll web.ll migrate status     # Show migration status
ll web.ll migrate rollback [n]  # Alias for down
```

## Configuration (`.env`)

| Key | Default | Description |
|-----|---------|-------------|
| `HOST` | `localhost` | Server bind address |
| `PORT` | `8000` | Server port |
| `DB` | `storage/llweb.db` | SQLite database path |
| `STATIC_DIR` | `static` | Static files directory |
| `VIEW_DIR` | `app/Views` | Template directory |
| `LAYOUT` | `layout` | Layout template name (without `.html`) |

## Routes

### Defining routes

In any controller file, call `router/add-route`:

```scheme
(router/add-route "GET" "/" IndexController 'index)
(router/add-route "GET" "/posts/:id" PostController 'show)
(router/add-route "POST" "/posts" PostController 'create)
```

Route patterns support `:param` segments — they are passed to the controller method as an alist in the `params` slot.

### Route aggregator

All controllers are imported via `app/Routes.ll`:

```scheme
; app/Routes.ll
(import "Controllers/Index")
(import "Controllers/Posts")
```

## Controllers

### Creating a controller

```scheme
; app/Controllers/Posts.ll
(import "lumetas/llweb/View")

(defclass PostController (Controller) ())

(router/add-route "GET" "/posts" PostController 'index)

(defmethod PostController index (self ctx)
  (return (View/render "Posts" (list
    (cons "title" "All Posts")))))
```

Controller methods receive `self` and `ctx` (a list of `(req params)`).

### Request data

```scheme
(defmethod PostController show (self ctx)
  (define req (car ctx))
  (define params (cadr ctx))

  ; Path parameters (from route pattern :id)
  (define id (cdr (assoc "id" params)))

  ; Request metadata (available via self slots)
  (define method (slot-ref self 'method))  ; "GET", "POST", etc.
  (define path (slot-ref self 'path))     ; Request path

  ; Headers and body (from raw request object)
  (define headers (http/request-headers req))
  (define body (http/request-body req))
  (define user-agent (cdr (assoc "User-Agent" headers)))

  ...)
```

## Responses

### Render a view

```scheme
(View/render "view-name" (list
  (cons "key" "value")))
```

Looks for `app/Views/view-name.html`. Template variables use `{{key}}` syntax.

If `app/Views/layout.html` exists, the rendered view is inserted as `{{content}}`.

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

### JSON response

```scheme
(defmethod PostController api (self ctx)
  (return (render-json (list
    (cons "status" "ok")
    (cons "count" 42)))))
```

### Redirect

```scheme
(defmethod PostController store (self ctx)
  (return (redirect "/posts")))
```

### Custom response

```scheme
(http/make-response 200
  (list (cons "Content-Type" "application/json"))
  "{\"key\": \"value\"}")
```

## Migrations

### Defining migrations

```scheme
; app/Migrations.ll
(Migration/register "001_create_posts"
  (lambda ()
    (schema/create-table "posts" (list
      (list 'id 'integer 'primary 'autoinc)
      (list 'title 'string)
      (list 'body 'text)
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
```

Column definition: `(list 'name 'type :option1 :option2 ...)`

Types: `integer`, `string`, `text`, `boolean`, `timestamp`, `float`, `decimal`

Options: `primary`, `autoinc`, `nullable`, `unique`, `default VALUE`

### CLI

```sh
ll web.ll migrate up              # Apply pending
ll web.ll migrate down            # Rollback last
ll web.ll migrate down 3          # Rollback 3
ll web.ll migrate status          # Show all with status
```

## Models

### Define and use

```scheme
(define posts (Model/new "posts" '(id title body created_at)))

; All records
(send posts 'all)

; Find by id
(send posts 'find 1)

; Where filter
(send posts 'where (list (cons "title" "Hello")))

; Create
(send posts 'create (list (cons "title" "New Post") (cons "body" "Content")))

; Count
(send posts 'count)
```

### Instance methods

```scheme
(define p (send posts 'find 1))
(send p 'get "title")     ; Read field
(send p 'set (list "title" "Updated"))  ; Update + persist
(send p 'delete)           ; Delete record
(send p 'reload)           ; Refresh from DB
```

### Functional API (backward compat)

```scheme
(model-all posts)
(model-find posts 1)
(model-create posts data)
(model-update posts 1 data)
(model-delete posts 1)
(model-where posts filters)
(model-count posts)
```

## Static Files

Files in the `static/` directory are served automatically at the matching URL path.

```
static/css/app.css  →  GET /css/app.css
static/js/main.js   →  GET /js/main.js
```

## Project Structure

```
.env                  # Configuration
web.ll                # CLI entry point
app/
  Controllers/        # Controller files
    Index.ll
  Models/             # Model definitions
  Views/              # HTML templates
    Welcome.html
    layout.html
  Routes.ll           # Route aggregator
  Migrations.ll       # Migration definitions
storage/              # SQLite database
static/               # Static assets
ll_modules/           # Framework modules
```
