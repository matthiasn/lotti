(ns meo.electron.renderer.ui.entry.utils
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [clojure.string :as s]
            [meo.common.utils.misc :as u]))

(defn entry-reaction [ts]
  (let [new-entries (subscribe [:new-entries])
        entries-map (subscribe [:entries-map])
        combined-entries (subscribe [:combined-entries])
        entry (reaction (get-in @combined-entries [ts]))
        edit-mode (reaction (contains? @new-entries ts))
        unsaved (reaction (and @edit-mode
                               (not= (u/clean-entry (get-in @new-entries [ts]))
                                     (u/clean-entry (get-in @entries-map [ts])))))]
    {:entry            entry
     :entries-map      entries-map
     :combined-entries combined-entries
     :new-entries      new-entries
     :unsaved          unsaved
     :edit-mode        edit-mode}))

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