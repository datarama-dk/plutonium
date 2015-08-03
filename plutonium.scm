#!/bin/csi -s
; ## PLUTONIUM ################################################################
; Static HTML generator with delusions of grandeur.
; Version: 0.1 (July 12, 2015)
; 
; Copyright (C) 2015 Simon Kongshøj <skongshoj@gmail.com>.
; 
; Permission is granted to anyone to use, copy, modify and/or distribute this
; software for any purpose, provided the following conditions are met:
; 
; 1. The authorship of the original software may not be misrepresented.
; 2. Altered source versions may not be misrepresented as the original.
; 3. This copyright notice must be retained in any source distribution.
; 
; This software is provided "as-is", without any warranty. The author
; will not be held liable for any damages arising from its use.

(use bindings utils srfi-19 regex lowdown filepath sxml-templates 
     string-utils lowdown-extra irregex uri-common)
(enable-lowdown-extra!)

; == Configuration ============================================================
(define date-format/file "~Y-~m-~d")
(define date-format/html "~B ~e, ~Y")
(define template-path "template/page.scm")
(define archive-feed "archive.list")
(define front-feed-size 6)
(define extension "pu")
(define default-lang "en")
(define max-rating 5)

; == Internal Variables =======================================================
(define amap '())
(define ramap '())
(define extractors '())
(define html-formatters '())
(define elements '())

(define (new-extractor! name func)
  (set! extractors (cons `(,name . ,func) extractors)))

(define (new-formatter! name func)
  (set! html-formatters (cons `(,name . ,func) html-formatters)))

(define (new-element! name func default)
  (set! elements (cons `(,name . ,func) elements)))

(define-syntax page-element
  (er-macro-transformer
    (lambda (e r c)
      (let ((name (cadr e)) (extract (caddr e)) (format (cadddr e)))
      `(begin
         (new-extractor! ',name (lambda (NAME TEXT VWCODE) ,extract))
         (new-formatter! ',name (lambda (ELEMENT) ,format)))))))

; == Page Titles ==============================================================
(define (extract-title path txt)
  (or (read-vwcode "%title" txt) (filepath:take-base-name path)))

(define (page-title path)
  (extract-title path (read-all path)))

; == Page Dates ===============================================================
(define (page-date path)
  (let* ((text (read-all path))
         (date (read-vwcode "%date" text)))
    (if date 
      (string->date date date-format/file) 
      (current-date))))

; == Wikilinks ================================================================
(define rx/link
  (irregex '(: "[[" (submatch-named link (*? (- any "\n"))) "]]")))
(define rx/desclink
  (irregex '(: "[[" (submatch-named link (*? (- any "]\n")))
               "|"  (submatch-named desc (*? (- any "\n"))) "]]")))

(define (desc-link? link)
  (irregex-match rx/desclink link))

(define (simple-link? link)
  (and (not (desc-link? link)) (irregex-match rx/link link)))

(define (link-file link) 
  (string-append link "." extension))

(define (link-name link)
  (cond ((simple-link? link)
         (irregex-match-substring (irregex-match rx/link link) 'link))
        ((desc-link? link)
         (irregex-match-substring (irregex-match rx/desclink link) 'desc))
        (else (error "Not a link!"))))

(define (link-target link)
  (cond ((simple-link? link)
         (irregex-match-substring (irregex-match rx/link link) 'link))
        ((desc-link? link)
         (irregex-match-substring (irregex-match rx/desclink link) 'link))
        (else (error "Not a link!"))))

(define (dead-wikilink? link)
  (or (not (file-exists? (link-file link)))
      (not (render? (link-file link)))))

(define (link-rating link)
  (let ((rating (read-vwcode "%rating" (read-all (link-file link)))))
    (if rating (string->number rating) #f)))

(define (get-wikilinks file)
  (map irregex-match-substring
    (irregex-fold rx/link
                  (lambda (i m s) (cons m s))
                  '()
                  (strip-vwcodes (read-all file))
                  (lambda (i s) (reverse s)))))
                  
; == VimWiki codes ============================================================
(define (read-vwcode code txt)
  (let ((cmatch
          (irregex-search
            (irregex `(seq bol ,code (submatch-named found (*? any)) eol))
            txt)))
    (if cmatch
      (string-trim-both (irregex-match-substring cmatch 'found))
      #f)))

; == Preprocessor =============================================================
(define (replace-wikilinks/desc txt)
  (irregex-replace/all 
    rx/desclink
    txt
    (lambda (x)
      (let ((link (irregex-match-substring x 'link))
            (desc (irregex-match-substring x 'desc)))
        (if (dead-wikilink? link) 
          desc
          (string-append "[" desc "](" (uri-encode-string link) ".html)"))))))

(define (replace-wikilinks/simple txt)
  (irregex-replace/all
    rx/link
    txt
    (lambda (x) 
      (let ((link (irregex-match-substring x 'link)))
        (if (dead-wikilink? link)
          link
          (string-append "<a href=\"" (uri-encode-string link) ".html\""
          (if (link-rating link)
            (string-append " class=star" (number->string (link-rating link)))
            "")
          ">" link "</a>"))))))

(define (replace-wikilinks txt)
  (replace-wikilinks/simple (replace-wikilinks/desc txt)))

(define (strip-vwcodes txt)
  (irregex-replace/all
    (irregex `(seq bol "%" (*? any) eol))
    txt
    ""))

(define (preprocess txt)
  (replace-wikilinks (strip-vwcodes txt)))

; == Sidebar Modules ==========================================================
(define (sidebar-links page)
  (let ((lfile (string-split (read-all (string-append page ".links")) "\n")))
    `(div (@ (class "sidebar-module-outer"))
          (div (@ (id "links") (class "sidebar-module"))
               (h2 ,(car lfile))
               (ul ,(map (lambda (l)
                           (let ((lnk (string-split l "|")))
                             `(li (a (@ (href ,(string-trim-both (cadr lnk)))) 
                                     ,(string-trim-both (car lnk))))))
                         (cdr lfile)))))))

(define (sidebar-activity page)
  `(div (@ (class "sidebar-module-outer"))
     (div (@ (id "recent-activity") (class "sidebar-module"))
       (h2 "Recent Activity")
       ,(render-activity (read-archivefeed)))))

(define sidebar-modules
  `((activity . ,sidebar-activity)
    (links    . ,sidebar-links)))

; == Data Extractors ==========================================================
(define (render? file)
  (not (read-vwcode "%nohtml" (read-all file))))

(define (nodropcap? txt) (read-vwcode "%nodropcap" txt))

(define (sidebar-list p modnames)
  (if modnames
    (map (lambda (x) 
           (lambda () ((cdr (assq x sidebar-modules)) 
                       (filepath:take-base-name p))))
         (map string->symbol (string-split modnames)))
    #f))


(define (exclude? element content)
  (read-vwcode (string-append "%no" (symbol->string element)) content))

(define (page-fields inpath)
  (and (render? inpath)
       (let* ((content (read-all inpath)))
         (map (lambda (x) 
                (cons (car x) 
                      (and (not (exclude? (car x) content))
                           ((cdr x) (filepath:take-base-name inpath) 
                                    content
                                    (read-vwcode (string-append "%"
                                                                (symbol->string (car x)))
                                                 content)))))
              extractors))))

(define (format-page page)
   (map (lambda (x)
          (cons (car x)
                (if (cdr x)
                  ((cdr (assq (car x) html-formatters)) (cdr x))
                  "")))
        page))

; == HTML rendering helpers ===================================================
(define (dropcapize sxml)
  (if (string? (car sxml))
    (cons `(span (@ (class "firstword"))
                 (span (@ (class "dropcap")) ,(string-take (car sxml) 1))
                 ,(string-drop (car sxml) 1))
          (cdr sxml))
    (cons (cons (caar sxml) (dropcapize (cdar sxml)))
          (cdr sxml))))

(define (mkdropcap sxml)
  (if (and (pair? sxml) (pair? (car sxml)) (eq? (caar sxml) 'p))
    (cons (cons 'p (dropcapize (cdar sxml)))
          (cdr sxml))
    sxml))

(define (rating->stars rating)
  (map (lambda (x) (if (> rating x) 
                     '(span (@ (class starred)) "★" )
                     '(span (@ (class unstarred)) "☆")))
       (iota max-rating)))

(define (rel->link rel)
  `(li (a (@ (href ,(string-append rel ".html"))) ,rel)))

(define (render-metadata head content)
  (if content
    `(div 
       (h2 ,head)
       ,content)
    ""))

(define (render-activity-entry entry)
  `(li (a (@ (href ,(string-append (archive-entry-page entry) ".html")))
          (span (@ (class "date"))
                ,(date->string (archive-entry-date entry) date-format/html))
          ,(if (link-rating (archive-entry-page entry)) "Review: " "")
          ,(archive-entry-title entry))))

(define (render-activity feed)
  `(ul ,(map render-activity-entry
               (if (> (length feed) front-feed-size)
                 (take feed front-feed-size)
                 feed))))

(define (render-sidebar mods)
  (map (lambda (x) (x)) mods))

; == Site Archive =============================================================
(define (archive-entry page title date) (cons page (cons date title)))
(define (archive-entry-page entry) (car entry))
(define (archive-entry-date entry) (cadr entry))
(define (archive-entry-title entry) (cddr entry))
(define (read-archivefeed) (car (read-file archive-feed)))

(define (save-archivefeed archive)
  (with-output-to-file archive-feed
    (lambda () (write archive))))

(define (update-feed entry feed)
  (let* ((page (archive-entry-page entry))
         (old (remove (lambda (x) (string=? page (archive-entry-page x))) feed)))
    (sort
      (filter 
        (lambda (x) (archive-entry-date x))
        (cons entry old))
      (lambda (x y) (date>? (archive-entry-date x) (archive-entry-date y))))))

(define (add-to-archive! path)
  (if (not (read-vwcode "%nodate" (read-all path)))
    (save-archivefeed 
      (update-feed (archive-entry (filepath:take-base-name path)
                                  (page-title path)
                                  (page-date path))
                   (read-archivefeed)))))

(define (render-archivefeed feed)
  `(ul (@ (id "archive")) 
       ,(map render-feed-entry feed)))

(define (render-feed-entry entry)
  `(li (span (@ (class "date"))
             ,(date->string (archive-entry-date entry) date-format/html))
       (a (@ (href ,(string-append (archive-entry-page entry) ".html")))
          ,(if (link-rating (archive-entry-page entry)) "Review: " "")
          ,(archive-entry-title entry))))

; == Association Maps =========================================================      
(define (amap-entry file)
  (cons (filepath:take-base-name file)
        (map link-target (get-wikilinks file))))
       
(define (generate-amap)
  (map amap-entry 
       (filter 
         (lambda (x) (and (not (string=? x "index.pu"))
                          (not (string=? x "archive.pu"))
                          (string-suffix? ".pu" x)))
         (directory))))
  
(define (ramap-entry node alst)
  (cons node 
    (map car
      (filter
        (lambda (x) (find (lambda (y) (string=? y node)) (cdr x)))
        alst))))
        
(define (reverse-amap alst)
  (map (lambda (x) (ramap-entry (car x) alst)) alst))

; Page Configuration ==========================================================
(page-element header-title
  (extract-title NAME TEXT)
  ELEMENT)

(page-element title
  (extract-title NAME TEXT)
  `(h1 (@ (id "pagetitle")) ,ELEMENT))

(page-element content
  (if (nodropcap? TEXT)
    (markdown->sxml (preprocess TEXT))
    (mkdropcap (markdown->sxml (preprocess TEXT))))
  ELEMENT)

(page-element lang
  (or VWCODE default-lang)
  ELEMENT)

(page-element meta
  VWCODE
  `(meta (@ (name "description") (content ,ELEMENT))))

(page-element sidebar 
  (sidebar-list NAME VWCODE)
  (render-sidebar ELEMENT))

(page-element author
  VWCODE
  (render-metadata "Author" ELEMENT))

(page-element pageclass
  (string-append "page_" (irregex-replace 
                           "[^a-zA-Z0-9]" 
                           NAME
                           "_"))
  ELEMENT)

(page-element date
  (if VWCODE (string->date VWCODE date-format/file) (current-date))
  (render-metadata "Date" (date->string ELEMENT date-format/html)))

(page-element rating
  (and VWCODE (string->number VWCODE))
  (render-metadata "Rating" (rating->stars ELEMENT)))

(page-element related
  (and (assoc NAME ramap) (sort (cdr (assoc NAME ramap)) string<?))
  (render-metadata "Related" 
    (and (not (null? ELEMENT)) `(ul ,(map rel->link ELEMENT)))))

; == Output ===================================================================
(define (output-page page outpath)
  (call-with-output-file outpath
    (lambda (out) 
      (if page (display (string-append "<!DOCTYPE HTML>\n" page) out)))))

(define (prep-output formatted)
  (sxml-template:fill-string page-template (format-page formatted)))

(define (generate-page inpath)
  (prep-output (page-fields inpath)))

(define (generate-archive-page feed)
  (prep-output
      (cons `(content . ,(render-archivefeed feed))
            (page-fields (string-append "archive." extension)))))

(define (generate-front-page)
  (prep-output (page-fields (string-append "index." extension))))

(define (output-path input-file output-dir)
  (filepath:combine output-dir
                    (filepath:replace-extension 
                      (filepath:take-file-name input-file)
                      "html")))

; == Driver ===================================================================
(define (run args)
  (let* ((force?     (not (= 0 (string->number (list-ref args 0)))))
         (syntax     (list-ref args 1))
         (file-extension  (list-ref args 2))
         (output-dir (list-ref args 3))
         (input-file (list-ref args 4))
         (input-dir  (filepath:take-directory input-file))
         (outpath    (output-path input-file output-dir))
         (outpath/front (filepath:combine output-dir "index.html"))
         (outpath/archive (filepath:combine output-dir "archive.html")))
    (if (string=? syntax "markdown")
      (begin
        (change-directory input-dir)
        (set! extension file-extension)
        (set! amap (generate-amap))
        (set! ramap (reverse-amap amap))
        (set! page-template 
          (make-sxml-template 
            (read (open-input-file 
                    (filepath:combine input-dir template-path)))))
        
        (add-to-archive! input-file)
        (output-page (generate-page input-file) outpath)
        (output-page (generate-archive-page (read-archivefeed))
                     outpath/archive)
        (output-page (generate-front-page) outpath/front)
        (exit 0))
      (error "This script only supports Markdown."))))

(run (command-line-arguments))

; /* vim: set filetype=scheme : */ 
