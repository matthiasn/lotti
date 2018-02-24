(ns meo.electron.renderer.ui.entry.briefing
  (:require [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.charts.data :as cd]
            [meo.electron.renderer.ui.charts.common :as cc]
            [meo.common.utils.misc :as u]
            [meo.electron.renderer.ui.entry.briefing.tasks :as tasks]
            [meo.electron.renderer.ui.entry.briefing.habits :as habits]
            [meo.electron.renderer.ui.entry.briefing.time :as time]
            [reagent.core :as r]
            [moment]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.entry.actions :as a]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [clojure.string :as s]))

(defn planned-actual [entry]
  (let [chart-data (subscribe [:chart-data])
        sagas (subscribe [:sagas])
        y-scale 0.0045]
    (fn [entry]
      (let [{:keys [pomodoro-stats]} @chart-data
            day (-> entry :briefing :day)
            day-stats (get pomodoro-stats day)
            allocation (-> entry :briefing :time-allocation)
            sagas @sagas
            actual-times (:time-by-saga day-stats)
            remaining (cd/remaining-times actual-times allocation)
            rect (fn [entity x v y]
                   (let [h (* y-scale v)
                         x (inc (* y-scale x))
                         entity-name (or (:saga-name (get sagas entity)) "none")]
                     ^{:key (str entity)}
                     [:rect {:fill   (cc/item-color entity-name)
                             :y      y
                             :x      x
                             :width  h
                             :height 9}]))
            legend (fn [text x y]
                     [:text {:x           x
                             :y           y
                             :stroke      "none"
                             :fill        "#333"
                             :text-anchor :left
                             :style       {:font-size 7}}
                      text])]
        (when (seq allocation)
          [:svg.planned-actual
           {:shape-rendering "crispEdges"
            :style           {:height "41px"}}
           [:g
            [:line {:x1           1
                    :x2           260
                    :y1           38
                    :y2           38
                    :stroke-width 0.5
                    :stroke       "#333"}]
            (for [h (range 16)]
              (let [x (inc (* y-scale h 60 60))
                    stroke-w (if (zero? (mod h 3)) 1.5 0.5)]
                ^{:key h}
                [:line {:x1           x
                        :x2           x
                        :y1           36
                        :y2           40.5
                        :stroke-width stroke-w
                        :stroke       "#333"}]))
            (for [[entity {:keys [x v]}] (cd/time-by-entity-stacked allocation)]
              (rect entity x v 3))
            (for [[entity {:keys [x v]}] (cd/time-by-entity-stacked actual-times)]
              (rect entity x v 14))
            (for [[entity {:keys [x v]}] (cd/time-by-entity-stacked remaining)]
              (rect entity x v 25))
            [legend "allocation" 3 10]
            [legend "actual" 3 21]
            [legend "remaining" 3 32]]])))))

(defn sagas-filter [local]
  (let [sagas (subscribe [:sagas])
        saga-select (fn [ev]
                      (let [v (js/parseInt (-> ev .-nativeEvent .-target .-value))
                            selected (when (pos? v) v)]
                        (swap! local assoc-in [:selected] selected)))]
    (fn sagas-filter-render [local]
      ^{:key (:selected @local)}
      [:select {:value     (:selected @local "")
                :on-change saga-select}
       [:option ""]
       (for [[ts saga] (sort-by #(s/lower-case (:saga-name (second %))) @sagas)]
         ^{:key ts}
         [:option {:value ts} (:saga-name saga)])])))

(defn briefing-view [entry put-fn local-cfg]
  (let [chart-data (subscribe [:chart-data])
        cfg (subscribe [:cfg])
        ts (:timestamp entry)
        {:keys [entry edit-mode entries-map]} (eu/entry-reaction ts)
        last-update (subscribe [:last-update])
        day (-> entry :briefing :day)
        today (.format (moment.) "YYYY-MM-DD")
        filter-btn (if (= day today) :active :open)
        local (r/atom {:filter                  filter-btn
                       :outstanding-time-filter true
                       :on-hold                 false})]
    (fn briefing-render [entry put-fn local-cfg]
      (h/keep-updated2 :stats/wordcount day local @last-update put-fn)
      (h/keep-updated2 :stats/pomodoro day local @last-update put-fn)
      (h/keep-updated2 :stats/tasks day local @last-update put-fn)
      (for [ts (:linked-entries-list entry)]
        (put-fn [:entry/find {:timestamp ts}]))
      (let [ts (:timestamp entry)
            {:keys [pomodoro-stats task-stats wordcount-stats]} @chart-data
            day (-> entry :briefing :day)
            day-stats (get pomodoro-stats day)
            excluded (:excluded (:briefing @cfg))
            logged-s (->> day-stats
                          :time-by-saga
                          (filter (fn [[s _]] (not (contains? excluded s))))
                          (map second)
                          (apply +))
            dur (u/duration-string logged-s)
            word-stats (get wordcount-stats day)
            {:keys [tasks-cnt done-cnt closed-cnt]} (get task-stats day)
            time-allocation (-> entry :briefing :time-allocation)]
        [:div.briefing

         ; rethink this
         ; [planned-actual entry]
         ; [time/time-by-sagas entry day-stats local edit-mode? put-fn]
         [:div.header
          [sagas-filter local]
          [a/briefing-actions ts put-fn @edit-mode local-cfg]]
         [:div.briefing-details
          [tasks/started-tasks local local-cfg put-fn]
          [tasks/open-linked-tasks ts local local-cfg put-fn]
          [habits/waiting-habits entry local local-cfg put-fn]]
         [:div.summary
          [:div
           "Tasks: " [:strong tasks-cnt] " created | "
           [:strong done-cnt] " done | "
           [:strong closed-cnt] " closed | Words: "
           [:strong (or (:word-count word-stats) 0)]]
          [:div
           (when (seq time-allocation)
             [:span
              "Total planned: "
              [:strong
               (u/duration-string
                 (apply + (map second time-allocation)))]])
           (when (seq dur)
             [:span
              " Logged: " [:strong dur] " in " (:total day-stats) " entries."])]]]))))
