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
(import \"Controllers/Index\")

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

(write-file (string-append *root* "/app/Controllers/Index.ll")
"(import \"lumetas/llweb/View\")

(defclass IndexController (Controller) ())

(router/add-route \"GET\" \"/\" IndexController 'index)

(defmethod IndexController index (self ctx)
  (return (View/render \"Welcome\" (list
    (cons \"title\" \"Home — LLWeb\")
    (cons \"message\" \"Your Lum Lisp web application is ready. Start building something incredible.\")
    (cons \"version\" \"0.0.1\")))))")

(write-file (string-append *root* "/app/Views/Welcome.html") (file->string (string-append *root* "/ll_modules/lumetas/llweb/init/Welcome.html")))

(println "")
    (println "Done! Project created at: " *root*)
    (println "")
    (println "Next steps:")
	(println "	ll migrate.ll up")
    (println "	ll main.ll")
