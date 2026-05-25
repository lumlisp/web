; LLWeb Init — project scaffolding
; Usage: ll ll_modules/lumetas/llweb/init.ll <project-name>

(define (dir path)
  (begin (system (string-append "mkdir -p " path)) (println "  created " path)))

(define (write-file path content)
  (system (string-append "cat > " path " << 'LLEOF'\n" content "\nLLEOF"))
  (println "  created " path))

(begin
	(define *root* ".")
		(println "LLWeb — Initializing project: " *root*))

(dir (string-append *root* "/app/Controllers"))
(dir (string-append *root* "/app/Models"))
(dir (string-append *root* "/app/Views"))
(dir (string-append *root* "/app/Views/posts"))
(dir (string-append *root* "/static/css"))
(dir (string-append *root* "/static/js"))
(dir (string-append *root* "/storage"))

(write-file (string-append *root* "/.env")
"HOST=localhost
PORT=8000
DB=storage/llweb.db")

(write-file (string-append *root* "/main.ll")
"(import \"lumetas/llweb/bootstrap\")
(add-module-path \"app\")
(llweb/set-static \"static\")
(db/init)

(import \"Migrations\")
(import \"Controllers/Home\")

(migration/up)

(llweb/start)")

(write-file (string-append *root* "/migrate.ll")
"; LLWeb Migration CLI
; Usage: ll migrate.ll <command> [args]

(import \"lumetas/llweb/bootstrap\")
(add-module-path \"app\")
(db/init)

(define args *args*)

(if (null? args)
  (begin
    (println \"Usage: ll migrate.ll <command> [args]\")
    (println \"Commands: up, down [n], status, rollback [n]\"))
  (begin
    (import \"Migrations\")
    (define cmd (car args))
    (cond
      ((string=? cmd \"up\") (migration/up))
      ((string=? cmd \"down\")
        (if (not (null? (cdr args)))
          (migration/rollback (string->number (cadr args)))
          (migration/down)))
      ((string=? cmd \"rollback\")
        (if (not (null? (cdr args)))
          (migration/rollback (string->number (cadr args)))
          (migration/down)))
      ((string=? cmd \"status\") (migration/status))
      (else (println \"Unknown command: \" cmd)))))")

(write-file (string-append *root* "/app/Migrations.ll")
"; LLWeb — Migration definitions

(Migration/register \"001_create_posts\"
  (lambda ()
    (schema/create-table \"posts\" (list
      (list 'id 'integer 'primary 'autoinc)
      (list 'title 'string)
      (list 'body 'text)
      (list 'created_at 'timestamp 'default \"CURRENT_TIMESTAMP\"))))
  (lambda ()
    (schema/drop-table \"posts\")))")

(write-file (string-append *root* "/app/Controllers/Home.ll")
"(import \"lumetas/llweb/View\")

(defclass HomeController (Controller) ())

(router/add-route \"GET\" \"/\" HomeController 'index)

(defmethod HomeController index (self ctx)
  (return (View/render \"index\" (list
    (cons \"title\" \"Home — LLWeb\")
    (cons \"param\" \"hello from LL!\")
    (cons \"param2\" \"MVC framework\")
    (cons \"param3\" \"lumetas/llweb\")))))")

(write-file (string-append *root* "/app/Views/layout.html")
"<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"UTF-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
<title>{{title}}</title>
<link rel=\"stylesheet\" href=\"/css/app.css\">
</head>
<body>
<nav>
  <a href=\"/\">Home</a>
  <a href=\"/posts\">Posts</a>
  <a href=\"/posts/create\">New Post</a>
</nav>
<main>
{{flash}}
{{content}}
</main>
<script src=\"/js/app.js\"></script>
</body>
</html>")

(write-file (string-append *root* "/app/Views/index.html")
"<section>
  <h1>LLWeb</h1>
  <p>{{param}}</p>
  <p>{{param2}}</p>
  <p>{{param3}}</p>
</section>")

(write-file (string-append *root* "/static/css/app.css")
"* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: system-ui, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 1rem; }
nav { padding: 1rem 0; border-bottom: 2px solid #eee; margin-bottom: 2rem; }
nav a { margin-right: 1rem; color: #0066cc; text-decoration: none; }
nav a:hover { text-decoration: underline; }
h1 { margin-bottom: 1rem; }
.flash { padding: 0.75rem; background: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px; margin-bottom: 1rem; }")

(write-file (string-append *root* "/static/js/app.js")
"console.log('LLWeb app loaded');")

(println "")
    (println "Done! Project created at: " *root*)
    (println "")
    (println "Next steps:")
	(println "	ll migrate.ll up")
    (println "	ll main.ll")
