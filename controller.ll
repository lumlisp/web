; LLWeb Controller — base class

(defclass Controller ()
  ((req ()) (params ()) (method "") (path "") (view-data ())))

(defmethod Controller render (self view-name data)
  (View/render view-name data))

(defmethod Controller render-json (self data)
  (http/make-response 200
    (list (cons "Content-Type" "application/json"))
    (json/encode data)))

(defmethod Controller redirect (self url)
  (http/make-response 302
    (list (cons "Location" url)) ""))
