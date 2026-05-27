; LLWeb Model — class-based data layer with parameterized queries

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

; --- Query helpers ---
(define (db/exec sql)
  (pdo/exec *db-conn* sql))

(define (db/query sql)
  (pdo/query *db-conn* sql))

; --- Parameterized helpers (no apply in LL) ---
(define (db/exec0 sql)
  (pdo/exec *db-conn* sql))

(define (db/exec1 sql p1)
  (pdo/exec *db-conn* sql p1))

(define (db/exec2 sql p1 p2)
  (pdo/exec *db-conn* sql p1 p2))

(define (db/exec3 sql p1 p2 p3)
  (pdo/exec *db-conn* sql p1 p2 p3))

(define (db/exec4 sql p1 p2 p3 p4)
  (pdo/exec *db-conn* sql p1 p2 p3 p4))

(define (db/exec5 sql p1 p2 p3 p4 p5)
  (pdo/exec *db-conn* sql p1 p2 p3 p4 p5))

(define (db/exec6 sql p1 p2 p3 p4 p5 p6)
  (pdo/exec *db-conn* sql p1 p2 p3 p4 p5 p6))

(define (db/exec-list sql params)
  (define len (length params))
  (cond
    ((= len 0) (db/exec0 sql))
    ((= len 1) (db/exec1 sql (car params)))
    ((= len 2) (db/exec2 sql (car params) (cadr params)))
    ((= len 3) (db/exec3 sql (car params) (cadr params) (caddr params)))
    ((= len 4) (db/exec4 sql (car params) (cadr params) (caddr params) (cadddr params)))
    ((= len 5) (db/exec5 sql (car params) (cadr params) (caddr params) (cadddr params)
                    (list-ref params 4)))
    ((= len 6) (db/exec6 sql (car params) (cadr params) (caddr params) (cadddr params)
                    (list-ref params 4) (list-ref params 5)))
    (else (error "db/exec-list: too many params (" len ")"))))

(define (db/query0 sql)
  (pdo/query *db-conn* sql))

(define (db/query1 sql p1)
  (pdo/query *db-conn* sql p1))

(define (db/query2 sql p1 p2)
  (pdo/query *db-conn* sql p1 p2))

(define (db/query3 sql p1 p2 p3)
  (pdo/query *db-conn* sql p1 p2 p3))

(define (db/query4 sql p1 p2 p3 p4)
  (pdo/query *db-conn* sql p1 p2 p3 p4))

(define (db/query-list sql params)
  (define len (length params))
  (cond
    ((= len 0) (db/query0 sql))
    ((= len 1) (db/query1 sql (car params)))
    ((= len 2) (db/query2 sql (car params) (cadr params)))
    ((= len 3) (db/query3 sql (car params) (cadr params) (caddr params)))
    ((= len 4) (db/query4 sql (car params) (cadr params) (caddr params) (cadddr params)))
    (else (error "db/query-list: too many params (" len ")"))))

; --- Model class ---
(defclass Model ()
  ((table-name "")
   (columns ())
   (data ())
   (query-order "")
   (query-limit 0)
   (query-offset 0)))

; --- Create a model class instance ---
(define (Model/new table-name columns)
  (define inst (new Model 'table-name table-name 'columns columns))
  (println "[model] registered: " table-name)
  inst)

; --- Internal: build WHERE clause with params ---
(define (model/build-where filters)
  (if (null? filters)
    (list "" ())
    (begin
      (define clauses (map (lambda (f) (string-append (car f) " = ?")) filters))
      (define vals (map (lambda (f) (cdr f)) filters))
      (list (string-append " WHERE " (string-join clauses " AND ")) vals))))

(define (model/build-suffix self)
  (define parts ())
  (define order (slot-ref self 'query-order))
  (if (> (string-length order) 0)
    (set! parts (append parts (list "ORDER BY" order))))
  (define limit (slot-ref self 'query-limit))
  (if (> limit 0)
    (set! parts (append parts (list "LIMIT" (number->string limit)))))
  (define offset (slot-ref self 'query-offset))
  (if (> offset 0)
    (set! parts (append parts (list "OFFSET" (number->string offset)))))
  (if (null? parts) "" (string-append " " (string-join parts " "))))

; --- Query builder methods (fluent) ---
(defmethod Model order (self column)
  (slot-set! self 'query-order column)
  self)

(defmethod Model limit (self n)
  (slot-set! self 'query-limit n)
  self)

(defmethod Model offset (self n)
  (slot-set! self 'query-offset n)
  self)

(defmethod Model reset-query (self)
  (slot-set! self 'query-order "")
  (slot-set! self 'query-limit 0)
  (slot-set! self 'query-offset 0)
  self)

; --- Class-level CRUD ---

(defmethod Model all (self)
  (define suffix (model/build-suffix self))
  (define sql (string-append "SELECT * FROM " (slot-ref self 'table-name) suffix))
  (define rows (db/query0 sql))
  (send self 'reset-query)
  (map (lambda (row)
    (new Model 'table-name (slot-ref self 'table-name)
              'columns (slot-ref self 'columns)
              'data row))
    rows))

(defmethod Model find (self id)
  (define rows (db/query1
    (string-append "SELECT * FROM " (slot-ref self 'table-name) " WHERE id = ?")
    id))
  (send self 'reset-query)
  (if (null? rows) ()
    (new Model 'table-name (slot-ref self 'table-name)
              'columns (slot-ref self 'columns)
              'data (car rows))))

(defmethod Model create (self data)
  (define cols (string-join (map car data) ", "))
  (define placeholders (string-join (map (lambda (_) "?") data) ", "))
  (define params (map (lambda (p) (cdr p)) data))
  (db/exec-list (string-append "INSERT INTO " (slot-ref self 'table-name)
    " (" cols ") VALUES (" placeholders ")") params)
  (new Model 'table-name (slot-ref self 'table-name)
            'columns (slot-ref self 'columns)
            'data data))

(defmethod Model where (self filters)
  (define w (model/build-where filters))
  (define suffix (model/build-suffix self))
  (define where-clause (car w))
  (define where-vals (cadr w))
  (define sql (string-append "SELECT * FROM " (slot-ref self 'table-name) where-clause suffix))
  (define rows (db/query-list sql where-vals))
  (send self 'reset-query)
  (map (lambda (row)
    (new Model 'table-name (slot-ref self 'table-name)
              'columns (slot-ref self 'columns)
              'data row))
    rows))

(defmethod Model count (self)
  (define suffix (model/build-suffix self))
  (define sql (string-append "SELECT COUNT(*) AS cnt FROM " (slot-ref self 'table-name) suffix))
  (define rows (db/query0 sql))
  (send self 'reset-query)
  (if (null? rows) 0
    (string->number (cdr (assoc "cnt" (car rows))))))

; --- Instance-level methods ---

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
    (db/exec2 (string-append "UPDATE " (slot-ref self 'table-name)
      " SET " field " = ? WHERE id = ?")
      value (string->number (cdr id-pair))))
  value)

(defmethod Model update (self updates)
  (define id-pair (assoc "id" (slot-ref self 'data)))
  (if id-pair
    (begin
      (define cols (map car updates))
      (define vals (map (lambda (p) (cdr p)) updates))
      (define set-clause (string-join (map (lambda (c) (string-append c " = ?")) cols) ", "))
      (define all-vals (append vals (list (string->number (cdr id-pair)))))
      (db/exec-list (string-append "UPDATE " (slot-ref self 'table-name)
        " SET " set-clause " WHERE id = ?") all-vals)
      (define new-data (slot-ref self 'data))
      (for-each (lambda (p) (set! new-data (acons (car p) (cdr p) new-data))) updates)
      (slot-set! self 'data new-data)))
  self)

(defmethod Model delete (self)
  (define id-pair (assoc "id" (slot-ref self 'data)))
  (if id-pair
    (db/exec1 (string-append "DELETE FROM " (slot-ref self 'table-name) " WHERE id = ?")
      (string->number (cdr id-pair)))))

(defmethod Model reload (self)
  (define id-pair (assoc "id" (slot-ref self 'data)))
  (if id-pair
    (begin
      (define rows (db/query1
        (string-append "SELECT * FROM " (slot-ref self 'table-name) " WHERE id = ?")
        (string->number (cdr id-pair))))
      (if (not (null? rows))
        (slot-set! self 'data (car rows))))))

; --- Relationships ---

(defmethod Model has-many (self related-table foreign-key)
  (define related (Model/new related-table ()))
  (send related 'where (list (cons foreign-key (cdr (assoc "id" (slot-ref self 'data)))))))

(defmethod Model belongs-to (self related-table foreign-key)
  (define related (Model/new related-table ()))
  (send related 'find (string->number (cdr (assoc foreign-key (slot-ref self 'data))))))

; --- Backward-compatible wrappers ---
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
    (string-append (car p) " = ?")) data) ", "))
  (define vals (map (lambda (p) (cdr p)) data))
  (define all-vals (append vals (list id)))
  (db/exec-list (string-append "UPDATE " (slot-ref m 'table-name)
    " SET " set-clause " WHERE id = ?") all-vals))

(define (model-delete m id)
  (db/exec1 (string-append "DELETE FROM " (slot-ref m 'table-name) " WHERE id = ?") id))

(define (model-where m filters)
  (define result (send m 'where filters))
  (map (lambda (inst) (slot-ref inst 'data)) result))

(define (model-count m)
  (send m 'count))
