(ns meo.electron.renderer.ui.new-entries
  (:require [meo.electron.renderer.ui.entry.entry :as e]
            [re-frame.core :refer [subscribe]]))

(defn new-entries-view
  "Renders view for editing new entries. New entries are those that are only
   persisted in localstorage and not yet in the backend."
  [put-fn]
  (let [entries-map (subscribe [:entries-map])
        new-entries (subscribe [:new-entries])]
    (fn new-entries-render [put-fn]
      (let [entries-map @entries-map
            new-entries @new-entries
            filtered-entries (filter #(and
                                        (not (:comment_for %))
                                        (:timestamp %)
                                        (not (contains? entries-map (:timestamp %))))
                                     (vals new-entries))]
        (when (seq filtered-entries)
          [:div.new-entries
           [:div.new-entries-list
            (for [entry filtered-entries]
              ^{:key (:timestamp entry)}
              [e/entry-with-comments (:timestamp entry) put-fn {}])]])))))
