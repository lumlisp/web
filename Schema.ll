; LLWeb Schema — migration DSL without raw SQL

(define (type->sql type)
  (cond
    ((eq? type 'integer) "INTEGER")
    ((eq? type 'string) "TEXT")
    ((eq? type 'text) "TEXT")
    ((eq? type 'boolean) "INTEGER")
    ((eq? type 'timestamp) "TEXT")
    ((eq? type 'datetime) "TEXT")
    ((eq? type 'float) "REAL")
    ((eq? type 'decimal) "REAL")
    ((eq? type 'bigint) "INTEGER")
    ((eq? type 'blob) "BLOB")
    (else "TEXT")))

(define (type-not-null? type)
  (or (eq? type 'string) (eq? type 'text) (eq? type 'integer) (eq? type 'bigint)))

(define (col->sql col)
  (define col-name (symbol->string (car col)))
  (define col-type (cadr col))
  (define extras (cddr col))
  (define type-str (type->sql col-type))
  (define has-primary (member 'primary extras))
  (define has-autoinc (member 'autoinc extras))
  (define has-nullable (member 'nullable extras))
  (define has-unique (member 'unique extras))
  (define has-default (member 'default extras))
  (define has-unsigned (member 'unsigned extras))
  (define parts (list col-name type-str))
  (if (and (type-not-null? col-type) (not has-nullable))
    (set! parts (append parts (list "NOT NULL"))))
  (if has-primary
    (set! parts (append parts (list "PRIMARY KEY"))))
  (if has-autoinc
    (set! parts (append parts (list "AUTOINCREMENT"))))
  (if has-unique
    (set! parts (append parts (list "UNIQUE"))))
  (if has-unsigned
    (set! parts (append parts (list "CHECK(" col-name " >= 0)"))))
  (if has-default
    (begin
      (define (find-def lst)
        (if (null? lst) ""
          (if (eq? (car lst) 'default)
            (if (not (null? (cdr lst)))
              (begin
                (define dv (cadr lst))
                (if (string? dv) dv (symbol->string dv)))
              "")
            (find-def (cdr lst)))))
      (define dv (find-def extras))
      (if (> (string-length dv) 0)
        (set! parts (append parts (list "DEFAULT" dv))))))
  (string-join parts " "))

(define (schema/create-table name columns)
  (define col-parts (map col->sql columns))
  (define indexes ())
  (define idx-counter 1)
  (for-each (lambda (col)
    (define extras (cddr col))
    (if (member 'index extras)
      (begin
        (define idx-name (string-append "idx_" name "_" (symbol->string (car col))))
        (set! indexes (append indexes (list
          (string-append "CREATE INDEX IF NOT EXISTS " idx-name
            " ON " name " (" (symbol->string (car col)) ")")))))))
    columns)
  (define sql (string-append "CREATE TABLE IF NOT EXISTS " name " ("
    (string-join col-parts ", ") ")"))
  (db/exec sql)
  (for-each (lambda (idx) (db/exec idx)) indexes)
  (println "[schema] created table: " name))

(define (schema/drop-table name)
  (db/exec (string-append "DROP TABLE IF EXISTS " name))
  (println "[schema] dropped table: " name))

(define (schema/add-column table col)
  (define col-def (col->sql col))
  (db/exec (string-append "ALTER TABLE " table " ADD COLUMN " col-def))
  (println "[schema] added column to " table ": " (symbol->string (car col))))

(define (schema/drop-column table col-name)
  (db/exec (string-append "ALTER TABLE " table " DROP COLUMN " col-name))
  (println "[schema] dropped column from " table ": " col-name))

(define (schema/rename-table old new)
  (db/exec (string-append "ALTER TABLE " old " RENAME TO " new))
  (println "[schema] renamed table: " old " -> " new))

; --- Index management ---

(define (schema/create-index table columns . name)
  (define idx-name (if (null? name)
    (string-append "idx_" table "_" (string-join columns "_"))
    (car name)))
  (define cols (string-join (map (lambda (c)
    (if (pair? c) (string-append (car c) " " (cadr c)) c)) columns) ", "))
  (db/exec (string-append "CREATE INDEX IF NOT EXISTS " idx-name " ON " table " (" cols ")"))
  (println "[schema] created index: " idx-name " on " table))

(define (schema/drop-index name)
  (db/exec (string-append "DROP INDEX IF EXISTS " name))
  (println "[schema] dropped index: " name))
