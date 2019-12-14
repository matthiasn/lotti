(ns meins.electron.renderer.ui.entry.briefing.calendar
  (:require ["cldr-data" :as cldr-data]
            ["globalize" :as globalize]
            ["moment" :as moment]
            ["react-big-calendar" :as rbc]
            ["react-infinite-calendar" :as ric]
            [matthiasn.systems-toolbox.component :as st]
            [meins.common.utils.parse :as up]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.charts.common :as cc]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [info]]))

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
                                  (up/parse-entry md)
                                  {:briefing      {:day ymd}
                                   :timestamp     (st/now)
                                   :timezone      h/timezone
                                   :utc-offset    (.getTimezoneOffset (new js/Date))
                                   :primary_story (-> @cfg :briefing :story)})]
                      (info "creating briefing" ymd)
                      (emit [:entry/update entry])))
                  (h/to-day ymd pvt))
        onSelect (fn [ev] (data-fn (h/ymd ev)))]
    (fn []
      (let [h (* (- (aget js/window "innerHeight") 52) 0.40)
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
            :theme           {:weekdayColor "#667"
                              :headerColor  "#FF8C00"}
            :rowHeight       45
            :selected        @cal-day}]]]))))

(.load globalize (.entireSupplemental cldr-data))
(.load globalize (.entireMainFor cldr-data "en" "de" "fr" "es"))
(.locale globalize "de")

(defn event-prop-getter [event _start _end _isSelected]
  (clj->js {:style {:backgroundColor (.-bgColor event)
                    :color           (.-color event)}}))

(defn calendar-view []
  (let [cal (r/adapt-react-class rbc/Calendar)
        show-pvt (subscribe [:show-pvt])
        cal-day (subscribe [:cal-day])
        stories (subscribe [:stories])
        gql-res (subscribe [:gql-res])
        stats (reaction (:logged_time (:data (:logged-by-day @gql-res))))]
    (fn calendar-view-render []
      (let [today (h/ymd (st/now))
            day (or @cal-day today)
            xf (fn [entry]
                 (let [{:keys [completed manual adjusted_ts
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
                       linked-story (get-in entry [:story :timestamp])
                       story (get @stories linked-story)
                       story-name (get-in entry [:story :story_name])
                       font-color (or (get-in story [:font_color])
                                      (cc/item-color story-name "dark"))
                       badge-color (or (get-in story [:badge_color])
                                       (cc/item-color story-name "light"))
                       story-name (get-in story [:story_name] "none")
                       title (str (when story-name (str story-name " - ")) text)
                       open-ts (or comment_for timestamp 0)
                       click (up/add-search {:tab-group    :right
                                             :story-name   story-name
                                             :first-line   text
                                             :query-string open-ts} emit)]
                   {:title   title
                    :ts      timestamp
                    :click   click
                    :bgColor badge-color
                    :color   font-color
                    :start   (js/Date. start)
                    :end     (js/Date. end)}))
            events (map xf (:by_ts_cal @stats))
            localizer (rbc/globalizeLocalizer globalize)]
        [:div.cal
         [:div.cal-container
          [:div.big-calendar {:class (when-not @show-pvt "pvt")}
           [cal {:events            events
                 :date              (.toDate (moment. day))
                 :localizer         localizer
                 :defaultView       "day"
                 :eventPropGetter   event-prop-getter
                 :toolbar           false
                 :onNavigate        #(info :navigate %)
                 :onSelectEvent     #(let [click (:click (js->clj % :keywordize-keys true))]
                                       (click))
                 :showMultiDayTimes true}]]]]))))
