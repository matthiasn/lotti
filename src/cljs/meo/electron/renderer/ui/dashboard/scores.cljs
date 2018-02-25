(ns meo.electron.renderer.ui.dashboard.scores
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.dashboard.common :as dc]))

(defn scores-fn [stats k]
  (->> stats
       :questionnaires
       k
       (sort-by first)
       (filter #(seq (second %)))
       (map (fn [[ts m]] (assoc-in m [:timestamp] ts)))))

(defn scores-chart
  [{:keys [k score-k]} _put-fn]
  (let [stats (subscribe [:stats])
        show-pvt (subscribe [:show-pvt])
        scores (reaction (filter score-k (scores-fn @stats k)))]
    (fn scores-chart-render [{:keys [y k w h score-k start end mn mx color
                                     x-offset label scatter]} put-fn]
      (let [span (- end start)
            rng (- mx mn)
            scale (/ h rng)
            btm-y (+ y h)
            line-inc (if (> mx 100) 50 10)
            lines (filter #(zero? (mod % line-inc)) (range 1 rng))
            mapper (fn [idx itm]
                     (let [ts (:timestamp itm)
                           from-beginning (- ts start)
                           x (+ x-offset (* w (/ from-beginning span)))
                           v (score-k itm)
                           y (- btm-y (* (- v mn) scale))
                           s (str x "," y)]
                       {:x       x
                        :y       y
                        :ts      ts
                        :v       v
                        :starred (:starred itm)
                        :s       s}))]
        [:g
         (for [n lines]
           ^{:key (str k score-k n)}
           [dc/line (- btm-y (* n scale)) "#888" 1])
         (if scatter
           [dc/scatter-chart @scores mapper color]
           [dc/chart-line @scores mapper color put-fn])
         [dc/line y "#000" 2]
         [dc/line (+ y h) "#000" 2]
         [:rect {:fill :white :x 0 :y y :height (+ h 5) :width 190}]
         (when @show-pvt
           [dc/row-label label y h])]))))
