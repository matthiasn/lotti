(ns meo.electron.renderer.ui.entry.briefing.calendar
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [matthiasn.systems-toolbox.component :as st]
            [meo.common.utils.parse :as up]
            [taoensso.timbre :refer-macros [info]]
            [meo.electron.renderer.helpers :as h]
            [moment :as moment]
            [rome :as rome]
            [react-big-calendar]
            [meo.electron.renderer.ui.charts.common :as cc]
            [meo.common.utils.parse :as p]))

(defn rome-component [put-fn]
  (let [ref (atom nil)
        briefings (subscribe [:briefings])
        cfg (subscribe [:cfg])
        data-handler (fn [ymd]
                       (let [q (up/parse-search (str "b:" ymd))]
                         (info ymd)
                         (when-not (get @briefings ymd)
                           (let [weekday (.format (moment. ymd) "dddd")
                                 md (str "## " weekday "'s #briefing")
                                 entry (merge
                                         (p/parse-entry md)
                                         {:briefing      {:day ymd}
                                          :timestamp     (st/now)
                                          :timezone      h/timezone
                                          :utc-offset    (.getTimezoneOffset (new js/Date))
                                          :primary-story (-> @cfg :briefing :story)})]
                             (put-fn [:entry/update entry])))
                         (put-fn [:cal/to-day {:day ymd}])
                         (put-fn [:search/add {:tab-group :briefing :query q}])
                         (put-fn [:search/refresh])))
        opts (clj->js {:time             false
                       :monthsInCalendar 2})]
    (r/create-class
      {:display-name         "rome-cal"
       :component-did-update (fn [] (some-> @ref .focus))
       :component-did-mount  (fn [props]
                               (let [rome-elem (rome. @ref opts)]
                                 (.on rome-elem "data" data-handler))
                               (info :component-did-mount @ref (js->clj props)))
       :reagent-render       (fn [put-fn]
                               [:div.rome {:ref (fn [cmp] (reset! ref cmp))}])})))

(defn calendar-view [put-fn]
  (let [rbc (aget js/window "deps" "BigCalendar")
        default (aget rbc "default")
        cal (r/adapt-react-class default)
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
        [:div.cal-container
         [:div.big-calendar
          [cal (merge {:events     cal-entries
                       :date       (.toDate (moment. day))
                       :onNavigate #(info :navigate %)}
                      scroll-to)]]]))))
