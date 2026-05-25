; LLWeb MVC Framework — bootstrap/core
(define (cadr lst) (car (cdr lst)))
(define (cddr lst) (cdr (cdr lst)))
(define (caddr lst) (car (cdr (cdr lst))))
(define (cadddr lst) (car (cdr (cdr (cdr lst)))))
(import "lumetas/llweb/controller")
(import "lumetas/llweb/env")
(import "lumetas/llweb/Model")
(import "lumetas/llweb/Schema")
(import "lumetas/llweb/Migration")

(define (string-prefix? s prefix)
  (define len (string-length prefix))
  (and (>= (string-length s) len)
       (string=? (substring s 0 len) prefix)))

(define (string-suffix? s suffix)
  (define len-s (string-length s))
  (define len-suf (string-length suffix))
  (and (>= len-s len-suf)
       (string=? (substring s (- len-s len-suf) len-s) suffix)))

(define (string-find haystack needle)
  (define parts (string-split haystack needle))
  (if (> (length parts) 1)
    (string-length (car parts))
    -1))

(define (string-replace s old new)
  (string-join (string-split s old) new))

(define (for-each fn lst)
  (if (null? lst) ()
    (begin (fn (car lst)) (for-each fn (cdr lst)))))

(define (acons key val alist)
  (cons (cons key val) alist))

(define-macro (return val) val)

; --- State ---
(define *routes* ())
(define *static-dir* "static")
(define *env* ())

; --- Router ---
(define (router/add-route method path controller-class method-sym)
  (set! *routes* (append *routes* (list (list method path controller-class method-sym))))
  (println "[llweb] route " method " " path))

(define (split-path path)
  (if (string=? path "/") ()
    (string-split (if (string-prefix? path "/")
                    (substring path 1 (string-length path)) path) "/")))

(define (match-route method path)
  (define parts (split-path path))
  (define (try routes)
    (if (null? routes) ()
      (begin
        (define r (car routes))
        (define r-method (car r))
        (define r-path (cadr r))
        (define r-class (caddr r))
        (define r-sym (cadddr r))
        (define r-parts (split-path r-path))
        (if (and (string=? method r-method) (= (length parts) (length r-parts)))
          (begin
            (define result (extract-params parts r-parts ()))
            (if (not (null? result))
              (list r-class r-sym (cdr result))
              (try (cdr routes))))
          (try (cdr routes))))))
  (define (extract-params pp rp acc)
    (if (null? pp) (cons #t acc)
      (if (string=? (car pp) (car rp))
        (extract-params (cdr pp) (cdr rp) acc)
        (if (and (> (string-length (car rp)) 0)
                 (string=? (substring (car rp) 0 1) ":"))
          (extract-params (cdr pp) (cdr rp)
            (acons (substring (car rp) 1 (string-length (car rp))) (car pp) acc))
          ()))))
  (try *routes*))

; --- Static ---
(define (guess-mime path)
  (cond
    ((string-suffix? ".css" path) "text/css")
    ((string-suffix? ".js" path) "application/javascript")
    ((string-suffix? ".png" path) "image/png")
    ((string-suffix? ".jpg" path) "image/jpeg")
    ((string-suffix? ".jpeg" path) "image/jpeg")
    ((string-suffix? ".gif" path) "image/gif")
    ((string-suffix? ".svg" path) "image/svg+xml")
    ((string-suffix? ".ico" path) "image/x-icon")
    ((string-suffix? ".json" path) "application/json")
    ((string-suffix? ".html" path) "text/html")
    ((string-suffix? ".txt" path) "text/plain")
    ((string-suffix? ".pdf" path) "application/pdf")
    (else "application/octet-stream")))

(define (serve-static path)
  (define filepath (string-append *static-dir* path))
  (if (file-exists? filepath)
    (http/make-response 200
      (list (cons "Content-Type" (guess-mime filepath)))
      (file->string filepath))
    ()))

; --- Handler ---
(define (handle-request req)
  (define method (http/request-method req))
  (define path (http/request-path req))
  (define route (match-route method path))
  (if (not (null? route))
    (begin
      (define controller-class (car route))
      (define method-sym (cadr route))
      (define params (caddr route))
      (define instance (new controller-class
        'req req 'params params 'method method 'path path))
      (send instance method-sym (list req params)))
    (begin
      (define static-result (serve-static path))
      (if static-result static-result
        (http/make-response 404
          (list (cons "Content-Type" "text/plain")) "Not Found")))))

; --- Server ---
(define (llweb/set-static dir)
  (set! *static-dir* dir))

(define (llweb/start)
  (define host  (env "HOST" "localhost"))
  (define port (string->number (env "PORT" 8000)))
  (println "[llweb] starting on " host ":" port)
  (define server (http/create-server host port))
  (http/set-handler server handle-request)
  (http/start-server server))
