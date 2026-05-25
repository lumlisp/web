; LLWeb View Engine

(define *view-dir* (env "VIEW_DIR" "app/Views"))
(define *layout-name* (env "LAYOUT" "layout"))

(define (View/render view-name data)
  (define view-path (string-append *view-dir* "/" view-name ".html"))
  (if (file-exists? view-path)
    (begin
      (define content (file->string view-path))
      (define rendered (process-template content data))
      (define layout-path (string-append *view-dir* "/" *layout-name* ".html"))
      (if (file-exists? layout-path)
        (begin
          (define layout (file->string layout-path))
          (define layout-data (acons "content" rendered data))
          (define flash-val (if (assoc "flash" data) (cdr (assoc "flash" data)) ""))
          (define layout-data2 (acons "flash" flash-val layout-data))
          (define layout-data3 (acons "title" (if (assoc "title" data) (cdr (assoc "title" data)) "LLWeb") layout-data2))
          (define full (process-template layout layout-data3))
          (http/make-response 200
            (list (cons "Content-Type" "text/html"))
            full))
        (http/make-response 200
          (list (cons "Content-Type" "text/html"))
          rendered)))
    (http/make-response 404
      (list (cons "Content-Type" "text/plain"))
      (string-append "View not found: " view-name))))

(define (process-template template data)
  (define (process t)
    (define start (string-find t "{{"))
    (if (= start -1) t
      (begin
        (define end (string-find t "}}"))
        (if (= end -1) t
          (begin
            (define var-name (string-trim (substring t (+ start 2) end)))
            (define val-pair (assoc var-name data))
            (define val (if val-pair (cdr val-pair) ""))
            (define next-val (if (number? val) (number->string val) val))
            (string-append (substring t 0 start) next-val
              (process (substring t (+ end 2) (string-length t)))))))))
  (process template))
