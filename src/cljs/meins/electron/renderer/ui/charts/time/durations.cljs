(ns meins.electron.renderer.ui.charts.time.durations
  (:require ["moment" :as moment]
            [clojure.pprint :as pp]
            [meins.common.utils.misc :as u]
            [meins.electron.renderer.charts.data :as cd]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.charts.common :as cc]
            [meins.electron.renderer.ui.charts.time.twenty-four-hour :as tfh]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as rc]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [info]]))

(defn day-bars [day-stats local idx chart-h y-scale put-fn]
  (let [options (subscribe [:options])
        stories (subscribe [:stories])
        stacked-reducer (fn [acc [k v]]
                          (let [total (get acc :total 0)]
                            (-> acc
                                (assoc-in [:total] (+ total v))
                                (assoc-in [:items k :v] v)
                                (assoc-in [:items k :y] total))))]
    (fn [day-stats local idx chart-h y-scale put-fn]
      (let [mouse-enter-fn (cc/mouse-enter-fn local day-stats)
            mouse-leave-fn (cc/mouse-leave-fn local day-stats)
            stories @stories
            time-by-story (sort-by #(str (first %)) (:time-by-story day-stats))
            stacked (reduce stacked-reducer {} time-by-story)
            time-by-story2 (reverse (sort-by #(str (first %)) (:items stacked)))
            weekend? (cc/weekend? (:date_string day-stats))]
        [:g {:on-mouse-enter mouse-enter-fn
             :on-mouse-leave mouse-leave-fn}
         (for [[story {:keys [y v]}] time-by-story2]
           (let [h (* y-scale v)
                 y (- chart-h (+ h (* y-scale y)))
                 story-name (or (:story_name (get stories story)) "No story")]
             ^{:key (str story)}
             [:rect {:on-click (cc/open-day-fn v put-fn)
                     :fill     (cc/item-color story-name)
                     :x        (* 30 idx)
                     :y        y
                     :width    26
                     :height   h}]))
         (when weekend?
           [:rect {:fill    :white
                   :x       (* 30 idx)
                   :y       0
                   :opacity 0.5
                   :width   26
                   :height  chart-h}])]))))

(defn bars-by-story [indexed local chart-h y-scale put-fn]
  [:svg {:viewBox (str "0 0 600 " chart-h)}
   [:g
    [:g (for [[idx v] indexed]
          (let [h (* y-scale (:total-time v))
                mouse-enter-fn (cc/mouse-enter-fn local v)
                mouse-leave-fn (cc/mouse-leave-fn local v)]
            ^{:key (str idx)}
            [day-bars v local idx chart-h y-scale put-fn]))]
    [cc/chart-title "by story"]]])

;; TODO: either DRY up or rethink
(defn day-bars-by-saga
  "Renders group with rects for all stories of the particular day."
  [day-stats local idx chart-h y-scale put-fn]
  (let [options (subscribe [:options])
        sagas (subscribe [:sagas])
        stacked-reducer (fn [acc [k v]]
                          (let [total (get acc :total 0)]
                            (-> acc
                                (assoc-in [:total] (+ total v))
                                (assoc-in [:items k :v] v)
                                (assoc-in [:items k :y] total))))]
    (fn [day-stats local idx chart-h y-scale put-fn]
      (let [mouse-enter-fn (cc/mouse-enter-fn local day-stats)
            mouse-leave-fn (cc/mouse-leave-fn local day-stats)
            sagas @sagas
            time-by-saga (sort-by #(str (first %)) (:time-by-saga day-stats))
            stacked (reduce stacked-reducer {} time-by-saga)
            time-by-saga (reverse (sort-by #(str (first %)) (:items stacked)))
            weekend? (cc/weekend? (:date_string day-stats))]
        [:g
         {:on-mouse-enter mouse-enter-fn
          :on-mouse-leave mouse-leave-fn}
         (for [[saga {:keys [y v]}] time-by-saga]
           (let [h (* y-scale v)
                 y (- chart-h (+ h (* y-scale y)))
                 saga-name (or (:saga-name (get sagas saga)) "No saga")
                 weekday? (not (cc/weekend? (:date_string day-stats)))]
             ^{:key (str saga)}
             [:rect {:on-click (cc/open-day-fn v put-fn)
                     :fill     (cc/item-color saga-name)
                     :x        (* 30 idx)
                     :y        y
                     :width    26
                     :height   h}]))
         (when weekend?
           [:rect {:fill    :white
                   :x       (* 30 idx)
                   :y       0
                   :opacity 0.5
                   :width   26
                   :height  chart-h}])]))))

(defn bars-by-saga [indexed local chart-h y-scale put-fn]
  [:svg {:viewBox (str "0 0 600 " chart-h)}
   [:g
    [:g (for [[idx v] indexed]
          (let [h (* y-scale (:total-time v))
                mouse-enter-fn (cc/mouse-enter-fn local v)
                mouse-leave-fn (cc/mouse-leave-fn local v)]
            ^{:key (str idx)}
            [day-bars-by-saga v local idx chart-h y-scale put-fn]))]
    [cc/chart-title "by saga"]]])

(defn time-by-stories-list [day-stats]
  (let [stories (subscribe [:stories])
        sagas (subscribe [:sagas])]
    (fn [day-stats]
      (let [stories @stories
            sagas @sagas
            dur (u/duration-string (:total-time day-stats))
            date (:date_string day-stats)]
        (when date
          [:div.story-time
           [:table
            [:tbody
             [:tr [:th ""] [:th "saga"] [:th "total"]]
             (for [[saga-id v] (:time-by-saga day-stats)]
               (let [saga (get sagas saga-id)
                     saga-name (or (:saga-name saga) "none")
                     color (cc/item-color saga-name)]
                 ^{:key saga-id}
                 [:tr
                  [:td [:div.legend {:style {:background-color color}}]]
                  [:td [:strong saga-name]]
                  [:td.time (u/duration-string v)]]))]]
           [:table
            [:tbody
             [:tr [:th ""] [:th "story"] [:th "total"]]
             (for [[story v] (:time-by-story day-stats)]
               (let [story-name (or (:story_name (get stories story)) "none")
                     color (cc/item-color story-name)]
                 ^{:key story}
                 [:tr
                  [:td [:div.legend {:style {:background-color color}}]]
                  [:td [:strong story-name]]
                  [:td.time (u/duration-string v)]]))]]])))))

(defn durations-table
  [chart-h y-scale put-fn]
  (let [local (rc/atom {})
        chart-data (subscribe [:chart-data])
        stats (reaction (:pomodoro-stats @chart-data))
        last-update (subscribe [:last-update])
        cfg (subscribe [:cfg])
        show-pvt? (reaction (:show-pvt @cfg))
        idx-fn (fn [idx [k v]] [idx v])
        sagas (subscribe [:sagas])
        chart-data (subscribe [:chart-data])]
    (fn [chart-h y-scale put-fn]
      (let [sagas @sagas
            stats @stats
            indexed (map-indexed idx-fn stats)
            indexed-45 (map-indexed idx-fn (take-last 45 stats))
            day-stats (or (:mouse-over @local) (second (last stats)))
            expanded? (:expanded @local)
            past-7-days (->> stats
                             (cd/past-7-days :time-by-saga)
                             (sort-by second >))
            dur (u/duration-string (:total-time day-stats))
            fmt-date (.format (moment (:date_string day-stats)) "ddd YY-MM-DD")]
        (h/keep-updated :stats/pomodoro 60 local @last-update)
        [:div
         [:div.times-by-day
          [:div.story-time {:class (when expanded? "expanded")}
           [:div.content.white
            [:div {:on-click #(swap! local update-in [:expanded] not)}
             [:span.fa {:class (if expanded? "fa-compress" "fa-expand")}]]
            [:div
             "Past seven days: "
             [:strong (u/duration-string (apply + (map second past-7-days)))]]
            [:div [cc/horizontal-bar sagas :saga-name past-7-days 0.001]]
            [:table
             [:tbody
              [:tr [:th ""] [:th "saga"] [:th "total"]]
              (for [[saga-id v] (if expanded? past-7-days (take 10 past-7-days))]
                (let [saga (get sagas saga-id)
                      pvt-saga? (contains? (:tags saga) "#pvt")
                      saga-name (or (:saga-name saga) "none")
                      color (cc/item-color saga-name)]
                  (when pvt-saga? (prn saga))
                  (when (or @show-pvt? (not pvt-saga?))
                    ^{:key saga-id}
                    [:tr
                     [:td [:div.legend {:style {:background-color color}}]]
                     [:td [:strong saga-name]]
                     [:td.time (u/duration-string v)]])))]]
            (when expanded?
              [bars-by-saga indexed-45 local chart-h 0.0035 put-fn])
            (when expanded?
              [bars-by-story indexed-45 local chart-h 0.0035 put-fn])
            (when expanded?
              [:div.times-by-day
               [:div [:time fmt-date]
                " - " [:strong dur] " in " (:total day-stats) " entries."]
               [time-by-stories-list day-stats]])]]]]))))

(defn durations-bar-chart [chart-h y-scale put-fn]
  (let [local (rc/atom {})
        idx-fn (fn [idx v] [idx v])
        gql-res (subscribe [:gql-res])
        stats (reaction (:day-stats (:data (:day-stats @gql-res))))]
    (fn [chart-h y-scale put-fn]
      (let [stats @stats
            indexed (map-indexed idx-fn stats)]
        [:div.charts.durations
         [tfh/earlybird-nightowl indexed local :saga-name chart-h put-fn]
         ;[tfh/earlybird-nightowl indexed local :story_name chart-h put-fn]
         ]))))
