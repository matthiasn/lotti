(ns meo.electron.renderer.ui.entry.briefing.calendar
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [matthiasn.systems-toolbox.component :as st]
            [meo.common.utils.parse :as up]
            [taoensso.timbre :refer-macros [info]]
            [meo.electron.renderer.helpers :as h]
            [moment :as moment]
            [reagent.ratom :refer-macros [reaction]]
            [react-big-calendar]
            [react-infinite-calendar :as ric]
            [meo.electron.renderer.ui.charts.common :as cc]
            [meo.common.utils.parse :as p]
            [meo.electron.renderer.ui.entry.briefing.habits :as habits]))


(def infinite-cal-adapted
  (r/adapt-react-class (->> ric/Calendar
                            ric/withKeyboardSupport
                            ric/withDateSelection)))

(def infinite-cal-range-adapted
  (r/adapt-react-class (ric/withRange ric/Calendar)))

(defn infinite-cal [put-fn]
  (let [briefings (subscribe [:briefings])
        cfg (subscribe [:cfg])
        pvt (subscribe [:show-pvt])
        cal-day (subscribe [:cal-day])
        data-fn (fn [ymd]
                  (when-not (get @briefings ymd)
                    (let [weekday (.format (moment. ymd) "dddd")
                          md (str "## " weekday "'s #briefing")
                          entry (merge
                                  (p/parse-entry md)
                                  {:briefing      {:day ymd}
                                   :timestamp     (st/now)
                                   :timezone      h/timezone
                                   :utc-offset    (.getTimezoneOffset (new js/Date))
                                   :primary_story (-> @cfg :briefing :story)})]
                      (info "creating briefing" ymd)
                      (put-fn [:entry/update entry])))
                  (h/to-day ymd pvt put-fn))
        local (r/atom {:filter                  :all
                       :outstanding-time-filter true
                       :selected-set            #{}
                       :show-filter             false
                       :on-hold                 false})
        onSelect (fn [ev] (data-fn (h/ymd ev)))]
    (fn [put-fn]
      (let [h (- (aget js/window "innerHeight") 175)]
        [:div.inf-cal
         [:div.infinite-cal
          [infinite-cal-adapted
           {:width           "100%"
            :height          270
            :showHeader      false
            :onSelect        onSelect
            :autoFocus       true
            :keyboardSupport true
            :theme           {:weekdayColor "#666"
                              :headerColor  "#778"}
            :rowHeight       45
            :selected        @cal-day}]
          [:div.habit-details
           [habits/waiting-habits local put-fn]]]]))))

(defn calendar-view [put-fn]
  (let [rbc (aget js/window "deps" "BigCalendar")
        default (aget rbc "default")
        cal (r/adapt-react-class default)
        show-pvt (subscribe [:show-pvt])
        cal-day (subscribe [:cal-day])
        gql-res (subscribe [:gql-res])
        cfg (subscribe [:cfg])
        show-cal (reaction (:show-cal @cfg))
        stats (reaction (:logged_time (:data (:logged-by-day @gql-res))))]
    (fn calendar-view-render [put-fn]
      (let [today (h/ymd (st/now))
            day (or @cal-day today)
            xf (fn [entry]
                 (let [{:keys [completed manual story text
                               comment_for timestamp]} entry
                       start (if (pos? completed)
                               timestamp
                               (- timestamp (* manual 1000)))
                       end (if (pos? completed)
                             (+ timestamp (* completed 1000))
                             timestamp)
                       story-name (get-in story [:story_name])
                       saga-name (get-in story [:saga :saga_name]
                                         "none")
                       color (cc/item-color saga-name)
                       title (str (when story-name (str story-name " - "))
                                  text)
                       open-ts (or comment_for timestamp)
                       click (up/add-search open-ts :left put-fn)]
                   {:title title
                    :click click
                    :color color
                    :start (js/Date. start)
                    :end   (js/Date. end)}))
            events (map xf (:by_ts @stats))
            scroll-to (when (= today day)
                        {:scroll-to-date (js/Date. (- (st/now) (* 3 60 60 1000)))})]
        (when @show-cal
          [:div.cal
           [:div.cal-container
            [:div.big-calendar {:class (when-not @show-pvt "pvt")}
             [cal (merge {:events     events
                          :date       (.toDate (moment. day))
                          :onNavigate #(info :navigate %)}
                         scroll-to)]]]])))))
