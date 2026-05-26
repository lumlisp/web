; LLWeb Migrations

(define *migrations-table* "_migrations")
(define *migrations* ())

; --- Init ---
(define (migration/init)
  (db/exec (string-append
    "CREATE TABLE IF NOT EXISTS " *migrations-table*
    " (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, applied_at TEXT DEFAULT CURRENT_TIMESTAMP)")))

; --- Register migration (called by migration files) ---
(define (Migration/register name up-fn down-fn)
  (set! *migrations* (acons name (cons up-fn down-fn) *migrations*))
  (println "[migration] registered: " name))

; --- Query applied migrations ---
(define (migration/applied-names)
  (migration/init)
  (define rows (db/query (string-append "SELECT name FROM " *migrations-table* " ORDER BY id")))
  (map (lambda (r) (cdr (assoc "name" r))) rows))

(define (migration/pending-names)
  (define all-names (map car (reverse *migrations*)))
  (define applied (migration/applied-names))
  (filter (lambda (n) (not (member n applied))) all-names))

; --- Run pending migrations ---
(define (migration/up)
  (define pendings (migration/pending-names))
  (if (null? pendings)
    (println "[migration] all up to date")
    (for-each (lambda (name)
      (define pair (assoc name *migrations*))
      (define up-fn (car (cdr pair)))
      (println "[migration] applying: " name)
      (up-fn)
      (db/exec (string-append "INSERT INTO " *migrations-table* " (name) VALUES (\"" (escape-sql name) "\")"))
      (println "[migration] done: " name))
      pendings)))

; --- Rollback last N migrations ---
(define (migration/down) (migration/rollback 1))

(define (migration/rollback count)
  (migration/init)
  (define rows (db/query (string-append "SELECT name FROM " *migrations-table* " ORDER BY id DESC LIMIT " (number->string count))))
  (define names (map (lambda (r) (cdr (assoc "name" r))) rows))
  (for-each (lambda (name)
    (define pair (assoc name *migrations*))
    (define down-fn (cdr (cdr pair)))
    (println "[migration] rolling back: " name)
    (down-fn)
    (db/exec (string-append "DELETE FROM " *migrations-table* " WHERE name = \"" (escape-sql name) "\""))
    (println "[migration] rolled back: " name))
    names))

; --- Show status ---
(define (migration/status)
  (migration/init)
  (define applied (migration/applied-names))
  (println "=== Migration Status ===")
  (for-each (lambda (m)
    (define name (car m))
    (if (member name applied)
      (println "  [OK]  " name)
      (println "  [--]  " name)))
    (reverse *migrations*)))
