; LLWeb Init — project scaffolding
; Usage: ll ll_modules/lumetas/llweb/init.ll <project-name>

(define (dir path)
  (begin (system (string-append "mkdir -p " path)) (println "  created " path)))

(define (write-file path content)
  (string->file path content)
  (println "  created " path))

(begin
	(define *root* ".")
		(println "LLWeb — Initializing project: " *root*))

(dir (string-append *root* "/app/Controllers"))
(dir (string-append *root* "/app/Models"))
(dir (string-append *root* "/app/Views"))
(dir (string-append *root* "/app/client"))
(dir (string-append *root* "/storage"))

(write-file (string-append *root* "/.env")
"HOST=localhost
PORT=8000
DB=storage/llweb.db
STATIC_DIR=static
VIEW_DIR=app/Views
LAYOUT=layout")

(write-file (string-append *root* "/main.ll") (file->string (string-append *root* "/ll_modules/lumetas/llweb/init/main.ll")))

(write-file (string-append *root* "/app/Routes.ll")
"; LLWeb — Routes
; Import all controllers here

(import \"Controllers/Index\")")

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

(write-file (string-append *root* "/app/client/main.ll")
"; LLWeb Client Code
; This file is served at /c/main.ll
; Use @code(\"main.ll\") in your views to include it

(define (init)
  (display \"client loaded\"))
(init)")

(println "")
    (println "Done! Project created at: " *root*)
    (println "")
    (println "Next steps:")
	(println "	ll main.ll migrate up")
    (println "	ll main.ll serve")
