(ns meo.electron.renderer.ui.stats
  (:require [meo.electron.renderer.ui.charts.tasks :as ct]
            [meo.electron.renderer.ui.charts.custom-fields :as cf]
            [meo.electron.renderer.ui.charts.wordcount :as wc]
            [meo.electron.renderer.ui.charts.location :as loc]
            [meo.electron.renderer.ui.charts.time.durations :as cd]
            [meo.electron.renderer.ui.charts.media :as m]
            [meo.electron.renderer.helpers :as h]
            [re-frame.core :refer [subscribe]]
            [cljs.pprint :as pp]
            [meo.electron.renderer.ui.charts.award :as aw]))

(defn stats-text []
  (let [stats (subscribe [:stats])
        options (subscribe [:options])
        cfg (subscribe [:cfg])
        planning-mode (subscribe [:planning-mode])
        timing (subscribe [:timing])]
    (fn stats-text-render []
      (when stats
        [:div.stats-string
         (if @planning-mode
           [:div
            (:entry-count @stats) " entries | "
            (count (:hashtags @options)) " tags | "
            (count (:mentions @options)) " people | "
            (Math/floor (:hours-logged @stats)) " hours | "
            (:word-count @stats) " words | "
            (:open-tasks-cnt @stats) " open tasks | "
            (:backlog-cnt @stats) " backlog | "
            (:completed-cnt @stats) " done | "
            (:closed-cnt @stats) " closed | "
            (:import-cnt @stats) " #import"]
           [:div
            (:entry-count @stats) " entries | "
            (count (:hashtags @options)) " tags | "
            (count (:mentions @options)) " people | "
            (:word-count @stats) " words | "
            (:import-cnt @stats) " #import"])
         [:div
          "PID " (:pid @cfg)
          (when-let [ms (:query @timing)]
            (str ". Query with " (:count @timing)
                 " results: " ms))]]))))

(defn stats-view [put-fn]
  [:div.stats.charts
   [cd/durations-table 200 5 put-fn]
   [ct/tasks-chart 250 put-fn]
   [wc/wordcount-chart 150 put-fn 1000]
   [m/media-chart 150 put-fn]])
