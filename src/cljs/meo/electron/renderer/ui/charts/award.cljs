(ns meo.electron.renderer.ui.charts.award
  (:require [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.helpers :as h]
            [reagent.core :as r]))

(defn points-by-day-chart
  "Renders bars."
  [stats]
  (let [chart-h 22
        daily-totals (map (fn [[d v]] (h/add (:task v) (:habit v))) stats)
        max-val (apply max daily-totals)
        indexed (map-indexed (fn [idx [day v]] [idx [day v]])
                             (take-last 14 stats))]
    [:svg
     [:g
      (for [[idx [day v]] indexed]
        (let [v (h/add (:task v) (:habit v))
              y-scale (/ chart-h (or max-val 1))
              h (if (pos? v) (* y-scale v) 0)]
          (when (pos? max-val)
            ^{:key (str day idx)}
            [:rect {:x      (* 8 idx)
                    :y      (- chart-h h)
                    :fill   "#7FE283"
                    :width  7
                    :height h}])))
      (for [[idx [day v]] indexed]
        (let [v (:task v)
              y-scale (/ chart-h (or max-val 1))
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
  [put-fn]
  (let [stats (subscribe [:stats])
        last-update (subscribe [:last-update])
        local (r/atom {:last-fetched 0})]
    (fn [put-fn]
      (let [award-points (:award-points @stats)
            by-day (sort-by first (:by-day award-points))
            total (:total award-points 0)
            total-skipped (:total-skipped award-points 0)
            claimed (:claimed award-points 0)
            balance (- total claimed total-skipped)]
        [:div.award
         [:div.points [:span.fa.fa-diamond] balance]
         [:div
          [:span.total total]
          [:span.total-skipped total-skipped]
          [:span.claimed claimed]]
         [points-by-day-chart by-day]]))))
