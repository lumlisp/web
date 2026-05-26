; LLWeb Model — class-based data layer

; --- DB config ---
(define *db-conn* ())
(define *db-name* "storage/llweb.db")

(define (db/set-dir dir)
  (set! *db-name* (string-append dir "/llweb.db")))

(define (db/set-name name)
  (set! *db-name* name))

(define (file-dir path)
  (define parts (string-split path "/"))
  (if (= (length parts) 1) "."
    (string-join (take parts (- (length parts) 1)) "/")))

(define (db/init)
  (set! *db-name* (env "DB" "storage/llweb.db"))
  (define dir (file-dir *db-name*))
  (if (not (file-exists? dir))
    (begin
      (system (string-append "mkdir -p " dir))
      (println "[llweb] created db dir: " dir)))
  (set! *db-conn* (pdo/open "sqlite" *db-name*))
  (println "[llweb] db: " *db-name*))

(define (escape-sql s)
  (string-replace s "'" "''"))

; --- Raw SQL via PDO ---
(define (db/exec sql)
  (pdo/exec *db-conn* sql))

(define (db/query sql)
  (pdo/query *db-conn* sql))

; --- Model class ---
(defclass Model ()
  ((table-name "")
   (columns ())
   (data ())))

; --- Create a model class instance ---
(define (Model/new table-name columns)
  (define inst (new Model 'table-name table-name 'columns columns))
  (println "[model] registered: " table-name)
  inst)

; --- Class-level CRUD (call via send) ---

(defmethod Model all (self)
  (define rows (db/query (string-append "SELECT * FROM " (slot-ref self 'table-name))))
  (map (lambda (row)
    (new Model 'table-name (slot-ref self 'table-name)
              'columns (slot-ref self 'columns)
              'data row))
    rows))

(defmethod Model find (self id)
  (define rows (db/query
    (string-append "SELECT * FROM " (slot-ref self 'table-name) " WHERE id = " (number->string id))))
  (if (null? rows) ()
    (new Model 'table-name (slot-ref self 'table-name)
              'columns (slot-ref self 'columns)
              'data (car rows))))

(defmethod Model create (self data)
  (define cols (string-join (map car data) ", "))
  (define vals (string-join
    (map (lambda (p) (string-append "\"" (escape-sql (cdr p)) "\"")) data) ", "))
  (db/exec (string-append "INSERT INTO " (slot-ref self 'table-name) " (" cols ") VALUES (" vals ")"))
  (new Model 'table-name (slot-ref self 'table-name)
            'columns (slot-ref self 'columns)
            'data data))

(defmethod Model where (self filters)
  (if (null? filters)
    (send self 'all)
    (begin
      (define conditions (string-join
        (map (lambda (f) (string-append (car f) " = \"" (escape-sql (cdr f)) "\"")) filters) " AND "))
      (define rows (db/query
        (string-append "SELECT * FROM " (slot-ref self 'table-name) " WHERE " conditions)))
      (map (lambda (row)
        (new Model 'table-name (slot-ref self 'table-name)
                  'columns (slot-ref self 'columns)
                  'data row))
        rows))))

(defmethod Model count (self)
  (define rows (db/query (string-append "SELECT COUNT(*) AS cnt FROM " (slot-ref self 'table-name))))
  (if (null? rows) 0
    (string->number (cdr (assoc "cnt" (car rows))))))

; --- Instance-level methods (call via send on records) ---

(defmethod Model get (self field)
  (cdr (assoc field (slot-ref self 'data))))

(defmethod Model set (self args)
  (define field (car args))
  (define value (cadr args))
  (define data (slot-ref self 'data))
  (define id-pair (assoc "id" data))
  (define new-data (acons field value data))
  (slot-set! self 'data new-data)
  (if id-pair
    (db/exec (string-append "UPDATE " (slot-ref self 'table-name)
      " SET " field " = \"" (escape-sql value) "\""
      " WHERE id = " (cdr id-pair))))
  value)

(defmethod Model delete (self)
  (define id-pair (assoc "id" (slot-ref self 'data)))
  (if id-pair
    (db/exec (string-append "DELETE FROM " (slot-ref self 'table-name)
      " WHERE id = " (cdr id-pair)))))

(defmethod Model reload (self)
  (define id-pair (assoc "id" (slot-ref self 'data)))
  (if id-pair
    (begin
      (define rows (db/query
        (string-append "SELECT * FROM " (slot-ref self 'table-name)
          " WHERE id = " (cdr id-pair))))
      (if (not (null? rows))
        (slot-set! self 'data (car rows))))))

; --- Backward-compatible wrappers (old plist-based API) ---
(define (model-table m) (slot-ref m 'table-name))

(define (model-all m)
  (define result (send m 'all))
  (if (null? result) ()
    (map (lambda (inst) (slot-ref inst 'data)) result)))

(define (model-find m id)
  (define result (send m 'find id))
  (if result (slot-ref result 'data) ()))

(define (model-create m data)
  (send m 'create data)
  data)

(define (model-update m id data)
  (define set-clause (string-join (map (lambda (p)
    (string-append (car p) " = \"" (escape-sql (cdr p)) "\"")) data) ", "))
  (db/exec (string-append "UPDATE " (slot-ref m 'table-name)
    " SET " set-clause " WHERE id = " (number->string id))))

(define (model-delete m id)
  (db/exec (string-append "DELETE FROM " (slot-ref m 'table-name)
    " WHERE id = " (number->string id))))

(define (model-where m filters)
  (define result (send m 'where filters))
  (map (lambda (inst) (slot-ref inst 'data)) result))

(define (model-count m)
  (send m 'count))
