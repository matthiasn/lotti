(ns meo.jvm.export
  "This namespace does exports.
   The markdown-to-pdf conversion comes from https://github.com/yogthos/instant-pdf"
  (:require [markdown.core :as md]
            [clj-pdf.core :as p]
            [clojure.xml :as xml]
            [meo.jvm.file-utils :as fu]
            [clojure.tools.logging :as log])
  (:import [java.io ByteArrayInputStream]))


(defn parse-html [s]
  (prn s)
  (-> (str "<html>" s "</html>")
      (.getBytes)
      (ByteArrayInputStream.)
      xml/parse))

(def tag-map
  {:html       [{}]
   :h1         [:paragraph {:leading 20 :style :bold :size 14}]
   :h2         [:paragraph {:leading 20 :style :bold :size 12}]
   :h3         [:paragraph {:leading 20 :style :bold :size 10}]
   :hr         [:line]
   :br         [:spacer]
   :img        [:image]
   :pre        [:paragraph {:size 10 :family :courier}]
   :code       [:chunk {:family :courier :style :bold}]
   :p          [:paragraph]
   :b          [:chunk {:style :bold}]
   :em         [:chunk {:style :italic}]
   :del        [:chunk {:style :strikethru}]
   :ul         [:list {:numbered false}]
   :ol         [:list {:numbered true}]
   :li         [:chunk]
   :a          [:anchor]
   :sup        [:chunk {:super true}]
   :strong     [:chunk {:style :bold}]
   :blockquote [:paragraph {:style :italic :indent 5}]})

(defn set-attrs [content {:keys [href src title]}]
  (cond
    href (conj content {:target href})
    (and title src) [:paragraph {:align :center} (conj content src) title]
    src (into content [{:align :center} src])
    :else content))

(defn transform-node [{:keys [tag attrs content]}]
  (-> (or (tag tag-map) [:paragraph])
      (set-attrs attrs)
      (into content)))

(defn md-to-pdf [md out]
  (p/pdf
    (->> (md/md-to-html-string md)
         (parse-html)
         (clojure.walk/postwalk
           (fn [n] (prn :n n) (if (:tag n) (transform-node n) n))))
    out))

(defn export-pdf
  "Export entry to PDF."
  [{:keys [put-fn msg-payload]}]
  (let [{:keys [md timestamp]} msg-payload
        filename (str fu/export-path timestamp)
        pdf-filename (str filename ".pdf")
        md-filename (str filename ".md")]
    (spit md-filename md)
    ;    (md-to-pdf md pdf-filename)
    (log/info "exporting" pdf-filename md-filename)
    {:emit-msg [:search/refresh]}))

(defn cmp-map
  "Generates component map for imports-cmp."
  [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:export/pdf export-pdf}})
