(ns meo.electron.renderer.ui.entry.utils
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info debug]]
            [clojure.string :as s]
            [meo.common.utils.misc :as u]))

(defn compare-relevant [entry]
  (let [entry (dissoc (u/clean-entry entry)
                      :text :editor-state :vclock :last-saved :linked-entries
                      :edit-running :comments :linked)]
    (update-in entry [:md] #(when (string? %) (s/trim %)))))

(defn entry-reaction [ts]
  (let [new-entries (subscribe [:new-entries])
        entries-map (subscribe [:entries-map])
        combined-entries (subscribe [:combined-entries])
        entry (reaction (get-in @combined-entries [ts]))
        new-entry (reaction (get-in @new-entries [ts]))
        edit-mode (reaction (contains? @new-entries ts))
        unsaved (reaction (and @edit-mode
                               (:md @new-entry)
                               (not= (compare-relevant @new-entry)
                                     (compare-relevant @entry))))]
    {:entry            entry
     :new-entry        new-entry
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
