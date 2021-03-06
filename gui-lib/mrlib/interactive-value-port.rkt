#lang racket/base

  (require racket/pretty
           racket/gui/base
           racket/class
           "syntax-browser.rkt")
  (provide set-interactive-display-handler
           set-interactive-write-handler
           set-interactive-print-handler)

  (define op (current-output-port))
  (define (oprintf . x) (apply fprintf op x))
  
  (define (set-interactive-display-handler port #:snip-handler [snip-handler #f])
    (let ([original-port-display-handler (port-display-handler port)])
      (port-display-handler
       port
       (λ (val port)
         (cond
           [(string? val) (original-port-display-handler val port)]
           [else
            (do-printing pretty-display val port snip-handler)])))))
  
  (define (set-interactive-write-handler port #:snip-handler [snip-handler #f])
    (port-write-handler
     port
     (λ (val port)
       (do-printing pretty-write val port snip-handler))))
  
  (define (set-interactive-print-handler port #:snip-handler [snip-handler #f])
    (port-print-handler
      port
      (λ (val port)
        (do-printing pretty-print val port snip-handler))))
            
  (define (use-number-snip? x)
    (and #f
         (number? x)
         (exact? x)
         (real? x)
         (not (integer? x))))

  (define default-pretty-print-current-style-table (pretty-print-current-style-table))

  (define (do-printing pretty value port snip-handler)
    (parameterize (;; these handlers aren't used, but are set to override the user's settings
                   [pretty-print-print-line (λ (line-number op old-line dest-columns) 
                                                (when (and (not (equal? line-number 0))
                                                           (not (equal? dest-columns 'infinity)))
                                                  (newline op))
                                                0)]
                   [pretty-print-pre-print-hook (λ (val port) (void))]
                   [pretty-print-post-print-hook (λ (val port) (void))]
                   [pretty-print-columns 'infinity]
                   [pretty-print-exact-as-decimal #f]
                   [pretty-print-depth #f]
                   [pretty-print-.-symbol-without-bars #f]
                   [pretty-print-show-inexactness #f]
                   [pretty-print-abbreviate-read-macros #t]
                   [pretty-print-current-style-table default-pretty-print-current-style-table]
                   [pretty-print-remap-stylable (λ (x) #f)]
                   [pretty-print-print-line
                    (lambda (line port offset width)
                      (when (and (number? width)
                                 (not (eq? 0 line)))
                        (newline port))
                      0)]
                   
                   [pretty-print-size-hook
                    (λ (value display? port)
                      (cond
                        [(not (port-writes-special? port)) #f]
                        [(is-a? value snip%) 1]
                        [(syntax? value) 1]
                        [else #f]))]
                   [pretty-print-print-hook
                    (λ (value display? port)
                      (cond
                        [(is-a? value snip%)
                         (cond
                           [snip-handler
                            (snip-handler value port)]
                           [else
                            (write-special value port)])
                         1]
                        [(syntax? value)
                         (write-special (render-syntax/snip value))]
                        [else (void)]))])
      (pretty value port)))
