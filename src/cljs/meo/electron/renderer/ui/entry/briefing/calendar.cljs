(ns meo.electron.renderer.ui.entry.briefing.calendar
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [matthiasn.systems-toolbox.component :as st]
            [meo.common.utils.parse :as up]
            [meo.electron.renderer.helpers :as h]
            [moment]
            [react-big-calendar]
            [meo.electron.renderer.ui.charts.common :as cc]))

(defn calendar-view [put-fn]
  (let [cal (r/adapt-react-class (aget js/window "deps" "BigCalendar" "default"))
        chart-data (subscribe [:chart-data])
        sagas (subscribe [:sagas])
        cal-day (subscribe [:cal-day])
        stories (subscribe [:stories])]
    (fn calendar-view-render [put-fn]
      (let [today (h/ymd (st/now))
            day (or @cal-day today)
            {:keys [pomodoro-stats]} @chart-data
            day-stats (get-in pomodoro-stats [day])
            time-by-ts (:time-by-ts day-stats)
            sagas @sagas
            stories @stories
            mapper (fn [[ts entry]]
                     (let [{:keys [completed manual saga story
                                   comment-for]} entry
                           start (if (pos? completed)
                                   ts
                                   (- ts (* manual 1000)))
                           end (if (pos? completed)
                                 (+ ts (* completed 1000))
                                 ts)
                           saga-name (get-in sagas [saga :saga-name])
                           color (cc/item-color saga-name)
                           title (get-in stories [story :story-name])
                           open-ts (or comment-for ts)
                           click (up/add-search open-ts :left put-fn)]
                       {:title title
                        :click click
                        :color color
                        :start (js/Date. start)
                        :end   (js/Date. end)}))
            cal-entries (map mapper time-by-ts)
            scroll-to (when (= today day)
                        {:scroll-to-date (js/Date. (- (st/now) (* 3 60 60 1000)))})]
        [:div.big-calendar
         [cal (merge {:events cal-entries
                      :date   (.toDate (moment. day))}
                     scroll-to)]]))))
