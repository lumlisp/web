; LLWeb — unified CLI
; Usage: ll main.ll <command> [args]
;
; Commands:
;   serve                    Start HTTP server
;   serve dev                Start with hot reload
;   migrate up               Run pending migrations
;   migrate down [n]         Rollback last n migrations
;   migrate status           Show migration status
;   migrate rollback [n]     Alias for down
;   migrate reset            Rollback all migrations
;   migrate fresh            Drop all and re-migrate
;   generate controller <name>  Generate controller
;   generate model <name>       Generate model

(import "lumlisp/web/bootstrap")

(add-module-path "app")
(llweb/set-static (env "STATIC_DIR" "static"))
(db/init)

(define args *args*)

(define (start-dev)
  (define has-watcher (= (system "which inotifywait >/dev/null 2>&1") 0))
  (println "[llweb] dev server with hot reload")
  (if (not has-watcher)
    (println "[llweb] install inotify-tools for faster reload"))
  (while #t
    (begin
      (system "ll main.ll serve > /tmp/llweb.log 2>&1 & echo $! > /tmp/llweb.pid")
      (usleep 200)
      (define pid (string-trim (file->string "/tmp/llweb.pid")))
      (if has-watcher
        (system "inotifywait -r -e modify -e create -e delete -e move -q app/ .env 2>/dev/null")
        (begin
          (system "touch /tmp/llweb-ref 2>/dev/null")
          (while (string=? "" (shell->string "find app/ .env -newer /tmp/llweb-ref -type f 2>/dev/null | head -1"))
            (usleep 1000))))
      (println "[llweb] change detected, restarting...")
      (system (string-append "kill " pid " 2>/dev/null"))
      (usleep 500))))

(cond
  ((null? args)
    (println "Usage: ll main.ll <command> [args]")
    (println "")
    (println "Commands:")
    (println "  serve                    Start HTTP server")
    (println "  serve dev                Start with hot reload")
    (println "  migrate up               Run pending migrations")
    (println "  migrate down [n]         Rollback last n migrations")
    (println "  migrate status           Show migration status")
    (println "  migrate rollback [n]     Alias for down")
    (println "  migrate reset            Rollback all migrations")
    (println "  migrate fresh            Drop all and re-migrate")
    (println "  generate controller <name>  Generate controller")
    (println "  generate model <name>       Generate model"))

  ((string=? (car args) "serve")
    (begin
      (import "Migrations")
      (import "Routes")
      (migration/up)
      (if (and (not (null? (cdr args))) (string=? (cadr args) "dev"))
        (start-dev)
        (llweb/start))))

  ((string=? (car args) "migrate")
    (if (null? (cdr args))
      (println "Usage: ll main.ll migrate <up|down|status|rollback|reset|fresh> [n]")
      (begin
        (import "Migrations")
        (define cmd (cadr args))
        (cond
          ((string=? cmd "up") (migration/up))
          ((string=? cmd "down")
            (if (not (null? (cddr args)))
              (migration/rollback (string->number (caddr args)))
              (migration/down)))
          ((string=? cmd "rollback")
            (if (not (null? (cddr args)))
              (migration/rollback (string->number (caddr args)))
              (migration/down)))
          ((string=? cmd "reset") (migration/reset))
          ((string=? cmd "fresh") (begin (migration/fresh) (migration/up)))
          ((string=? cmd "status") (migration/status))
          (else (println "Unknown migrate command: " cmd))))))

  (else
    (println "Unknown command: " (car args))))
