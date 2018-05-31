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
            [taoensso.timbre :refer-macros [info debug]]
            [moment]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.entry.actions :as a]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [clojure.string :as s]
            [meo.electron.renderer.ui.entry.entry :as e]
            [meo.electron.renderer.ui.entry.briefing.calendar :as cal]))

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
       (for [[ts saga] (sort-by #(s/lower-case (or (:saga_name (second %)) ""))
                                @sagas)]
         ^{:key ts}
         [:option {:value ts} (:saga_name saga)])])))

(defn briefing-view [put-fn local-cfg]
  (let [gql-res (subscribe [:gql-res])
        briefing (reaction (:briefing (:data (:briefing @gql-res))))
        day-stats (reaction (:logged_time (:data (:logged-by-day @gql-res))))
        cfg (subscribe [:cfg])
        local (r/atom {:filter                  :open
                       :outstanding-time-filter true
                       :on-hold                 false})]
    (fn briefing-render [put-fn local-cfg]
      (let [ts (:timestamp @briefing)
            excluded (:excluded (:briefing @cfg))
            logged-s (->> @day-stats
                          :by_ts
                          (filter #(not (contains? excluded
                                                   (-> %
                                                       :story
                                                       :linked-saga
                                                       :timestamp))))
                          (map :summed)
                          (apply +))
            dur (u/duration-string logged-s)
            n (count (:by_ts @day-stats))
            drop-fn (a/drop-linked-fn @briefing cfg put-fn)]
        [:div.entry-with-comments
         [:div.entry
          [:div.briefing {:on-drop       drop-fn
                          :on-drag-over  h/prevent-default
                          :on-drag-enter h/prevent-default}
           [:div.header
            [sagas-filter local]
            [a/briefing-actions ts put-fn]]
           [:div.briefing-details
            [tasks/started-tasks local local-cfg put-fn]
            [tasks/open-linked-tasks ts local local-cfg put-fn]
            [habits/waiting-habits local local-cfg put-fn]]
           [:div.summary
            [:div
             "Tasks: " [:strong (:tasks_cnt @day-stats)] " created | "
             [:strong (:done_tasks_cnt @day-stats)] " done | "
             [:strong (:closed_tasks_cnt @day-stats)] " closed | Words: "
             [:strong (or (:word_count @day-stats) 0)]]
            [:div
             (when (seq dur)
               [:span
                " Logged: " [:strong dur] " in " n " entries."])]]]]
         [:div.comments
          (for [comment (:comments @briefing)]
            ^{:key (str "c" comment)}
            [e/journal-entry comment put-fn local-cfg])]]))))

(defn briefing-column-view
  [tab-group put-fn]
  (let [query-cfg (subscribe [:query-cfg])
        query-id (reaction (get-in @query-cfg [:tab-groups tab-group :active]))
        story (reaction (get-in @query-cfg [:queries @query-id :story]))
        search-text (reaction (get-in @query-cfg [:queries @query-id :search-text]))
        local-cfg (reaction {:query-id    @query-id
                             :search-text @search-text
                             :tab-group   tab-group
                             :story       @story})]
    (fn briefing-column-view-render [tab-group put-fn]
      [:div.briefing
       [cal/rome-component put-fn]
       [:div.tile-tabs
        [:div.journal
         [:div.journal-entries
          [briefing-view put-fn @local-cfg]]]]])))
