(ns meo.electron.renderer.ui.stats
  (:require [meo.electron.renderer.ui.charts.tasks :as ct]
            [meo.electron.renderer.ui.charts.wordcount :as wc]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.charts.time.durations :as cd]
            [meo.electron.renderer.ui.charts.media :as m]
            [electron :refer [remote]]
            [re-frame.core :refer [subscribe]]))

(defn stats-text []
  (let [gql-res (subscribe [:gql-res])
        stories (subscribe [:stories])
        stats (reaction (:data (:count-stats @gql-res)))
        version (.getVersion (aget remote "app"))]
    (fn stats-text-render []
      [:div.stats-string
       [:div
        "meo " [:span.highlight version] " | "
        (:entry_count @stats) " entries | "
        (:tag_count @stats) " tags | "
        (count @stories) " stories | "
        (:mention_count @stats) " people | "
        (:hours_logged @stats) " hours | "
        (:word_count @stats) " words | "
        (:open_tasks @stats) " open tasks | "
        (:backlog_count @stats) " backlog | "
        (:completed_count @stats) " done | "
        (:closed_count @stats) " closed | "
        (:import_count @stats) " #import | "
        (:screenshots @stats) " #screenshot | "
        (:active_threads @stats) " threads | PID "
        (:pid @stats) " | "
        " © Matthias Nehlsen"]])))

(defn stats-view [put-fn]
  [:div.stats.charts
   [cd/durations-table 200 5 put-fn]
   [ct/tasks-chart 250 put-fn]
   [wc/wordcount-chart 150 put-fn 1000]
   [m/media-chart 150 put-fn]])
