(ns meo.electron.renderer.ui.entry.briefing.calendar
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [matthiasn.systems-toolbox.component :as st]
            [meo.common.utils.parse :as up]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [taoensso.timbre :refer-macros [info]]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.charts.award :as ca]
            [moment :as moment]
            [reagent.ratom :refer-macros [reaction]]
            [react-big-calendar]
            [react-infinite-calendar :as ric]
            [meo.electron.renderer.ui.charts.common :as cc]
            [meo.common.utils.parse :as p]
            [meo.electron.renderer.ui.entry.briefing.habits :as habits]
            [meo.electron.renderer.ui.entry.utils :as eu]))

(def locales
  {:fr {:locale       (js/require "date-fns/locale/fr")
        :headerFormat "dddd, D MMM"
        :weekdays     ["Dim" "Lun" "Mar" "Mer" "Jeu", "Ven", "Sam"]
        :blank        "Aucune date selectionnee"}
   :de {:locale       (js/require "date-fns/locale/de")
        :headerFormat "dddd, DD. MMMM"
        :weekdays     ["SO" "MO" "DI" "MI" "DO", "FR", "SA"]
        :blank        "Kein Datum ausgewählt"}
   :en {:locale       (js/require "date-fns/locale/en")
        :headerFormat "dddd, D MMMM"
        :weekdays     ["Sun" "Mon" "Tue" "Wed" "Thu", "Fri", "Sat"]
        :blank        "No Date selected"}
   :es {:locale       (js/require "date-fns/locale/es")
        :headerFormat "dddd, D MMMM"}})

(def infinite-cal-adapted
  (r/adapt-react-class (->> ric/Calendar
                            ric/withKeyboardSupport
                            ric/withDateSelection)))

(def infinite-cal-range-adapted
  (r/adapt-react-class (ric/withRange ric/Calendar)))

(defn infinite-cal []
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
                      (emit [:entry/update entry])))
                  (h/to-day ymd pvt))
        local (r/atom {:filter                  :all
                       :outstanding-time-filter true
                       :selected-set            #{}
                       :show-filter             false
                       :on-hold                 false})
        onSelect (fn [ev] (data-fn (h/ymd ev)))]
    (fn []
      (let [h (* (- (aget js/window "innerHeight") 52) 0.45)
            locale (:locale @cfg :en)]
        [:div.inf-cal
         [:div.infinite-cal
          [infinite-cal-adapted
           {:width           "100%"
            :height          h
            :showHeader      true
            :locale          (clj->js (locale locales))
            :onSelect        onSelect
            :autoFocus       true
            :keyboardSupport true
            :theme           {:weekdayColor "#666"
                              :headerColor  "#778"}
            :rowHeight       45
            :selected        @cal-day}]
          [:div.habit-details
           [habits/waiting-habits local emit]]]]))))

(defn calendar-view []
  (let [rbc (aget js/window "deps" "BigCalendar")
        default (aget rbc "default")
        cal (r/adapt-react-class default)
        show-pvt (subscribe [:show-pvt])
        cal-day (subscribe [:cal-day])
        gql-res (subscribe [:gql-res])
        stats (reaction (:logged_time (:data (:logged-by-day @gql-res))))]
    (fn calendar-view-render []
      (let [today (h/ymd (st/now))
            day (or @cal-day today)
            xf (fn [entry]
                 (let [{:keys [completed manual story text adjusted_ts
                               comment_for timestamp]} entry
                       timestamp (js/parseInt timestamp)
                       adjusted_ts (when adjusted_ts (js/parseInt adjusted_ts))
                       ts (if (number? adjusted_ts) adjusted_ts timestamp)
                       start (if (pos? completed)
                               ts
                               (- ts (* manual 1000)))
                       end (if (pos? completed)
                             (+ ts (* completed 1000))
                             ts)
                       text (eu/first-line entry)
                       story-name (get-in story [:story_name] "none")
                       color (cc/item-color story-name)
                       title (str (when story-name (str story-name " - "))
                                  text)
                       open-ts (or comment_for timestamp 0)
                       click (up/add-search {:tab-group    :left
                                             :story-name   story-name
                                             :first-line   text
                                             :query-string open-ts} emit)]
                   {:title title
                    :click click
                    :color color
                    :start (js/Date. start)
                    :end   (js/Date. end)}))
            events (map xf (:by_ts_cal @stats))]
        [:div.cal
         [:div.cal-container
          [:div.big-calendar {:class (when-not @show-pvt "pvt")}
           [cal {:events            events
                 :date              (.toDate (moment. day))
                 :onNavigate        #(info :navigate %)
                 :showMultiDayTimes true}]]]]))))
