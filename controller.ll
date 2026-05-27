; LLWeb Controller — base class

(defclass Controller ()
  ((req ()) (params ()) (method "") (path "") (view-data ())))

(defmethod Controller render (self view-name data)
  (View/render view-name data))

(defmethod Controller render-status (self status view-name data)
  (define response (View/render view-name data))
  (if (pair? response)
    (begin
      (define old-status (http/response-status response))
      (define headers (http/response-headers response))
      (define body (http/response-body response))
      (http/make-response status headers body))
    response))

(defmethod Controller render-json (self data)
  (http/make-response 200
    (list (cons "Content-Type" "application/json"))
    (json/encode data)))

(defmethod Controller render-json-status (self status data)
  (http/make-response status
    (list (cons "Content-Type" "application/json"))
    (json/encode data)))

(defmethod Controller redirect (self url)
  (http/make-response 302
    (list (cons "Location" url)) ""))

(defmethod Controller redirect-back (self)
  (define headers (http/request-headers (slot-ref self 'req)))
  (define referer (cdr (assoc "Referer" headers)))
  (define url (if referer referer "/"))
  (http/make-response 302
    (list (cons "Location" url)) ""))

; --- Request body parsing ---

(defmethod Controller json-body (self)
  (define req (slot-ref self 'req))
  (define body (http/request-body req))
  (if (or (null? body) (string=? body "")) ()
    (json/decode body)))

(defmethod Controller form-body (self)
  (define req (slot-ref self 'req))
  (define body (http/request-body req))
  (if (or (null? body) (string=? body "")) ()
    (parse-query-string body)))

(defmethod Controller query-params (self)
  (define req (slot-ref self 'req))
  (define path (http/request-path req))
  (define qpos (string-find path "?"))
  (if (= qpos -1) ()
    (parse-query-string (substring path (+ qpos 1) (string-length path)))))

; --- CSRF Protection ---

(define *csrf-counter* 0)
(define *csrf-tokens* ())

(define (csrf/generate-token)
  (set! *csrf-counter* (+ *csrf-counter* 1))
  (define ts (string-trim (shell->string "date +%s%N 2>/dev/null || echo 1")))
  (define token (number->string (+ *csrf-counter* (string->number ts))))
  (set! *csrf-tokens* (acons token #t *csrf-tokens*))
  token)

(define (csrf/validate-token token)
  (define pair (assoc token *csrf-tokens*))
  (if pair
    (begin
      (set! *csrf-tokens* (filter (lambda (p) (not (string=? (car p) token))) *csrf-tokens*))
      #t)
    #f))

(defmethod Controller csrf-field (self)
  (define token (csrf/generate-token))
  (string-append "<input type=\"hidden\" name=\"_csrf\" value=\"" token "\" />"))

(defmethod Controller csrf-meta (self)
  (define token (csrf/generate-token))
  (string-append "<meta name=\"csrf-token\" content=\"" token "\" />"))

; --- Flash Messages ---

(define *flash-store* ())

(define (flash/set key val)
  (set! *flash-store* (acons key val *flash-store*)))

(define (flash/get key)
  (define pair (assoc key *flash-store*))
  (if pair
    (begin
      (set! *flash-store* (filter (lambda (p) (not (string=? (car p) key))) *flash-store*))
      (cdr pair))
    ""))

(define (flash/has? key)
  (not (null? (assoc key *flash-store*))))
