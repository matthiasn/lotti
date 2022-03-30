(ns meins.electron.renderer.ui.charts.award
  (:require [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]))

(defn points-by-day-chart
  "Renders bars."
  [stats]
  (let [by-day (sort-by :date_string (:by_day stats))
        chart-h 12
        daily-totals (map :task by-day)
        max-val (apply max daily-totals)
        indexed (map-indexed (fn [idx {:keys [date_string task]}] [idx [date_string task]])
                             (take-last 10 by-day))]
    [:svg {:width (+ 10 (* 8 (count indexed)))}
     [:g
      (for [[idx [day v]] indexed]
        (let [y-scale (/ chart-h (or max-val 1))
              h (if (pos? v) (* y-scale v) 0)]
          (when (pos? max-val)
            ^{:key (str day idx)}
            [:rect {:x      (* 8 idx)
                    :y      (- chart-h h)
                    :fill   "#42b8dd"
                    :width  7
                    :height h}])))]]))

(defn award-points
  "Simple view for points awarded."
  []
  (let [gql-res (subscribe [:gql-res])
        stats (reaction (:award_points (:data (:award-points @gql-res))))]
    (fn []
      (let [total (:total @stats 0)
            claimed (:claimed @stats 0)
            balance (- total claimed)]
        [:div.award
         [:div
          [:span.fa.fa-diamond] balance
          [:span.total total]
          [:span.claimed claimed]]
         [points-by-day-chart @stats]]))))
