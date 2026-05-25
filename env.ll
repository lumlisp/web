(define (env key default)
  (define (find-in-lines lines)
    (if (null? lines)
        default
        (begin
          (define line (car lines))
          (define trimmed (string-trim line))
          (if (or (= (string-length trimmed) 0)
                  (string=? (substring trimmed 0 1) "#"))
              (find-in-lines (cdr lines))
              (parse-line trimmed (cdr lines))))))
  
  (define (parse-line line rest)
    (define eq-pos (find-char line "=" 0))
    (if (eq? eq-pos #f)
        (find-in-lines rest)
        (begin
          (define env-key (string-trim (substring line 0 eq-pos)))
          (define env-val (string-trim (substring line (+ eq-pos 1) (string-length line))))
          (if (string=? env-key key)
              (strip-quotes env-val)
              (find-in-lines rest)))))
  
  (define (strip-quotes val)
    (if (and (>= (string-length val) 2)
             (or (and (string=? (substring val 0 1) "\"")
                      (string=? (substring val (- (string-length val) 1) (string-length val)) "\""))
                 (and (string=? (substring val 0 1) "'")
                      (string=? (substring val (- (string-length val) 1) (string-length val)) "'"))))
        (substring val 1 (- (string-length val) 1))
        val))
  
  (define (find-char str char pos)
    (if (>= pos (string-length str))
        #f
        (if (string=? (substring str pos (+ pos 1)) char)
            pos
            (find-char str char (+ pos 1)))))
  
  (if (file-exists? ".env")
      (find-in-lines (string-split (file->string ".env") "\n"))
      default))
