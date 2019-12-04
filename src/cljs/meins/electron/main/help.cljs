(ns meins.electron.main.help
  (:require [clojure.string :as s]
            [fs :refer [readFileSync]]
            [meins.electron.main.runtime :as rt]
            [taoensso.timbre :refer [debug error info warn]]))

(defn get-help [{:keys []}]
  (let [path (:manual-path rt/runtime-info)
        manual (str path "/manual.md")
        md (readFileSync manual "utf-8")
        md (s/replace md "./images/" (str path "/images/"))]
    {:emit-msg (with-meta [:help/manual {:md md}] {:window-id :broadcast})}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:help/get-manual get-help}})
