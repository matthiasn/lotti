(ns meins.electron.renderer.ui.entry.utils
  (:require [clojure.string :as s]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug info]]))

(defn entry-reaction [ts]
  (let [new-entries (subscribe [:new-entries])
        new-entry (reaction (get-in @new-entries [ts]))
        edit-mode (reaction (contains? @new-entries ts))]
    {:new-entry new-entry
     :edit-mode edit-mode}))

(defn first-line [entry]
  (let [text #(or (:text %) (:md %))]
    (some-> entry
            (text)
            (s/replace "#task" "")
            (s/replace "#habit" "")
            (s/replace "#pvt" "")
            (s/replace "#" "")
            (s/replace "@" "")
            s/trim
            s/split-lines
            first)))

(defn logged-total [new-entries entry]
  (apply + (map (fn [x]
                  (let [ts (:timestamp x)
                        p [:custom_fields "#duration" :duration]]
                    (+ (or (get-in new-entries [ts :completed_time])
                           (get-in x [:completed_time] 0))
                       (* 60 (get-in x p 0)))))
                (:comments entry))))
