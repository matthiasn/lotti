(ns meins.jvm.routes.help
  (:require [compojure.core :refer [GET]]
            [taoensso.timbre :refer [info debug]]
            [hiccup.page :refer [html5 include-css include-js]]
            [meins.jvm.file-utils :as fu]
            [markdown.core :as mc]
            [clojure.string :as s]))

(def help-route
  (GET "/help/manual.html" []
    (info "delivering manual")
    (let [filename (str fu/app-path "/doc/manual.md")
          md (slurp filename)
          html (mc/md-to-html-string md :heading-anchors true)]
      (html5
        {:lang "en"}
        [:head
         [:title "meins - the manual"]
         (include-css "../css/manual.css")]
        [:body [:div.md html]]))))

(def help-img-route
  (GET "/help/images/:img" [img]
    (info "delivering" img)
    (let [filename (str fu/app-path "/doc/images/" img)
          file (java.io.File. filename)]
      {:body file})))
