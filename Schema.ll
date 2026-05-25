; LLWeb Schema — migration DSL without raw SQL

(define (type->sql type)
  (cond
    ((eq? type 'integer) "INTEGER")
    ((eq? type 'string) "TEXT")
    ((eq? type 'text) "TEXT")
    ((eq? type 'boolean) "INTEGER")
    ((eq? type 'timestamp) "TEXT")
    ((eq? type 'float) "REAL")
    ((eq? type 'decimal) "REAL")
    (else "TEXT")))

(define (type-not-null? type)
  (or (eq? type 'string) (eq? type 'text) (eq? type 'integer)))

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
  (define parts (list col-name type-str))
  (if (and (type-not-null? col-type) (not has-nullable))
    (set! parts (append parts (list "NOT NULL"))))
  (if has-primary
    (set! parts (append parts (list "PRIMARY KEY"))))
  (if has-autoinc
    (set! parts (append parts (list "AUTOINCREMENT"))))
  (if has-unique
    (set! parts (append parts (list "UNIQUE"))))
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
  (define sql (string-append "CREATE TABLE IF NOT EXISTS " name " ("
    (string-join col-parts ", ") ")"))
  (db/exec sql)
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
