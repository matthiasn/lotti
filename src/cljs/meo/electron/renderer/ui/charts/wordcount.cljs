(ns meo.electron.renderer.ui.charts.wordcount
  (:require [reagent.core :as rc]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.charts.common :as cc]
            [meo.electron.renderer.helpers :as h]))

(defn wordcount-chart
  "Draws chart for wordcount per day. The size of the the bars scales
   automatically depending on the maximum count found in the data.
   On mouse-over on any of the bars, the date and the values for the date are
   shown in an info div next to the bars."
  [chart-h put-fn daily-target]
  (let [local (rc/atom {})
        chart-data (subscribe [:chart-data])
        stats (reaction (:wordcount-stats @chart-data))
        last-update (subscribe [:last-update])]
    (fn [chart-h put-fn daily-target]
      (let [indexed (map-indexed (fn [idx [_k v]] [idx v]) @stats)
            max-cnt (apply max (map (fn [[_idx v]] (:word-count v)) indexed))]
        (h/keep-updated :stats/wordcount 60 local @last-update)
        [:div
         [:svg
          {:viewBox (str "0 0 600 " chart-h)}
          [:g
           [cc/chart-title "Words per Day"]
           [cc/bg-bars indexed local chart-h :wordcount]
           (when (pos? max-cnt)
             (for [[idx v] indexed]
               (let [reserved 50
                     max-h (- chart-h reserved)
                     y-scale (/ max-h (or max-cnt 1))
                     cnt (:word-count v)
                     h (* y-scale cnt)
                     x (* 10 idx)
                     mouse-enter-fn (cc/mouse-enter-fn local v)
                     mouse-leave-fn (cc/mouse-leave-fn local v)
                     cls (cc/weekend-class
                           (if (< cnt daily-target) "tasks" "done") v)]
                 ^{:key (str "tbar" (:date_string v) idx)}
                 [:g {:on-mouse-enter mouse-enter-fn
                      :on-mouse-leave mouse-leave-fn
                      :on-click       (cc/open-day-fn v put-fn)}
                  [:rect {:x      x
                          :y      (+ (- max-h h) reserved)
                          :width  9
                          :height h
                          :class  cls}]])))]]
         (when (:mouse-over @local)
           [:div.mouse-over-info (cc/info-div-pos @local)
            [:div (:date_string (:mouse-over @local))]
            [:div "Words: " (:word-count (:mouse-over @local))]])]))))
