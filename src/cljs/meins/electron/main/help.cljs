(ns meins.electron.main.help
  (:require [taoensso.timbre :refer-macros [info debug error warn]]
            [meins.electron.main.runtime :as rt]
            [fs :refer [readFileSync]]
            [clojure.string :as s]))

(defn get-help [{:keys []}]
  (let [path (:manual-path rt/runtime-info)
        manual (str path "/manual.md")
        md (readFileSync manual "utf-8")
        md (s/replace md "./images/" (str path "/images/"))]
    {:emit-msg (with-meta [:help/manual {:md md}] {:window-id :broadcast})}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:help/get-manual get-help}})
