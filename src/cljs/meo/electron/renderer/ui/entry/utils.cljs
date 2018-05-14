(ns meo.electron.renderer.ui.entry.utils
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info debug]]
            [clojure.string :as s]
            [meo.common.utils.misc :as u]))

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
