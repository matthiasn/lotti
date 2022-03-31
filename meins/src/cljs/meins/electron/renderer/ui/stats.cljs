(ns meins.electron.renderer.ui.stats
  (:require [electron :refer [remote]]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer [reaction]]))

(defn stats-text [rt-info]
  (let [gql-res (subscribe [:gql-res])
        stories (subscribe [:stories])
        stats (reaction (:data (:count-stats @gql-res)))
        version (.getVersion (aget remote "app"))]
    (fn stats-text-render []
      [:div.stats-string
       [:div
        "meins " [:span.highlight version] " beta | "
        (:entry_count @stats) " entries | "
        (:tag_count @stats) " tags | "
        (count @stories) " stories | "
        (:mention_count @stats) " people | "
        (:hours_logged @stats) " hours | "
        (:word_count @stats) " words | "
        (:open_tasks @stats) " open tasks | "
        (:completed_count @stats) " done | "
        (:closed_count @stats) " closed | "
        (:import_count @stats) " #import | "
        (:screenshots @stats) " #screenshot | "
        (when rt-info
          [:span (:active_threads @stats)] " threads | PID ")
        (when rt-info
          [:span (:pid @stats) " | "])
        " © Matthias Nehlsen"]])))
