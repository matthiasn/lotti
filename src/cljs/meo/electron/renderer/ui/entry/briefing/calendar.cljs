(ns meo.electron.renderer.ui.entry.briefing.calendar
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [matthiasn.systems-toolbox.component :as st]
            [meo.common.utils.parse :as up]
            [taoensso.timbre :refer-macros [info]]
            [meo.electron.renderer.helpers :as h]
            [moment :as moment]
            [rome :as rome]
            [reagent.ratom :refer-macros [reaction]]
            [react-big-calendar]
            [meo.electron.renderer.ui.charts.common :as cc]
            [meo.common.utils.parse :as p]
            [meo.electron.renderer.graphql :as gql]))

(defn rome-component [put-fn]
  (let [ref (atom nil)
        briefings (subscribe [:briefings])
        cfg (subscribe [:cfg])
        pvt (subscribe [:show-pvt])
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
                                   :primary-story (-> @cfg :briefing :story)})]
                      (info "creating briefing" ymd)
                      (put-fn [:entry/update entry])))
                  (put-fn [:cal/to-day {:day ymd}])
                  (put-fn [:gql/query {:file "logged-by-day.gql"
                                       :id   :logged-by-day
                                       :prio 3
                                       :args [ymd]}])
                  (put-fn [:gql/query {:file "briefing.gql"
                                       :id   :briefing
                                       :prio 2
                                       :args [ymd @pvt @pvt]}]))
        opts (clj->js {:time             false
                       :initialValue     (:cal-day @cfg)
                       :monthsInCalendar 2})]
    (r/create-class
      {:display-name         "rome-cal"
       :component-did-update (fn [] (some-> @ref .focus))
       :component-did-mount  (fn [props]
                               (let [rome-elem (rome. @ref opts)]
                                 (.on rome-elem "data" data-fn))
                               (info :component-did-mount @ref (js->clj props)))
       :reagent-render       (fn [put-fn]
                               [:div.rome {:ref (fn [cmp] (reset! ref cmp))}])})))

(defn calendar-view [put-fn]
  (let [rbc (aget js/window "deps" "BigCalendar")
        default (aget rbc "default")
        cal (r/adapt-react-class default)
        show-pvt (subscribe [:show-pvt])
        cal-day (subscribe [:cal-day])
        gql-res (subscribe [:gql-res])
        stats (reaction (:logged-time (:data (:logged-by-day @gql-res))))]
    (fn calendar-view-render [put-fn]
      (let [today (h/ymd (st/now))
            day (or @cal-day today)
            xf (fn [entry]
                 (let [{:keys [completed manual story text
                               comment-for timestamp]} entry
                       start (if (pos? completed)
                               timestamp
                               (- timestamp (* manual 1000)))
                       end (if (pos? completed)
                             (+ timestamp (* completed 1000))
                             timestamp)
                       story-name (get-in story [:story-name])
                       saga-name (get-in story [:saga :saga-name]
                                         "none")
                       color (cc/item-color saga-name)
                       title (str (when story-name (str story-name " - "))
                                  text)
                       open-ts (or comment-for timestamp)
                       click (up/add-search open-ts :left put-fn)]
                   {:title title
                    :click click
                    :color color
                    :start (js/Date. start)
                    :end   (js/Date. end)}))
            events (map xf (:by-ts @stats))
            scroll-to (when (= today day)
                        {:scroll-to-date (js/Date. (- (st/now) (* 3 60 60 1000)))})]
        [:div.cal-container
         [:div.big-calendar {:class (when-not @show-pvt "pvt")}
          [cal (merge {:events     events
                       :date       (.toDate (moment. day))
                       :onNavigate #(info :navigate %)}
                      scroll-to)]]]))))
