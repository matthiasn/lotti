(ns meo.electron.renderer.ui.stats
  (:require [meo.electron.renderer.ui.charts.tasks :as ct]
            [meo.electron.renderer.ui.charts.wordcount :as wc]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.charts.time.durations :as cd]
            [meo.electron.renderer.ui.charts.media :as m]
            [re-frame.core :refer [subscribe]]))

(defn stats-text []
  (let [gql-res (subscribe [:gql-res])
        stats (reaction (:count-stats @gql-res))]
    (fn stats-text-render []
      [:div.stats-string
       [:div (:entry-count @stats) " entries | "
        (:tag-count @stats) " tags | "
        (:mention-count @stats) " people | "
        (:hours-logged @stats) " hours | "
        (:word-count @stats) " words | "
        (:open-tasks @stats) " open tasks | "
        (:backlog-count @stats) " backlog | "
        (:completed-count @stats) " done | "
        (:closed-count @stats) " closed | "
        (:import-count @stats) " #import"]] )))

(defn stats-view [put-fn]
  [:div.stats.charts
   [cd/durations-table 200 5 put-fn]
   [ct/tasks-chart 250 put-fn]
   [wc/wordcount-chart 150 put-fn 1000]
   [m/media-chart 150 put-fn]])
