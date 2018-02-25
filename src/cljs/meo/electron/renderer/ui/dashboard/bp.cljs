(ns meo.electron.renderer.ui.dashboard.bp
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.dashboard.common :as dc]))

(defn bp-chart [_ _put-fn]
  (let [show-pvt (subscribe [:show-pvt])]
    (fn [{:keys [y k score-k h start span mn mx x-offset label
                 w tag stats]} put-fn]
      (let [rng (- mx mn)
            scale (/ h rng)
            btm-y (+ y h)
            line-inc 10
            lines (filter #(zero? (mod % line-inc)) (range 1 rng))
            mapper (fn [k]
                     (fn [_idx [ymd _v]]
                       (let [measurements (get-in stats [ymd tag k])
                             points (map (fn [{:keys [v ts]}]
                                           (let [from-beginning (- ts start)
                                                 x (+ x-offset
                                                      (* w (/ from-beginning span)))
                                                 y (- btm-y (* (- v mn) scale))
                                                 s (str x "," y)]
                                             {:ymd ymd
                                              :v   v
                                              :x   x
                                              :y   y
                                              :ts  ts
                                              :s   s}))
                                         measurements)]
                         (filter :v points))))]
        [:g
         (for [n lines]
           ^{:key (str k score-k n)}
           [dc/line (- btm-y (* n scale)) "#888" 1])
         (for [n lines]
           ^{:key (str k score-k n)}
           [:text {:x           2008
                   :y           (- (+ btm-y 5) (* n scale))
                   :font-size   8
                   :fill        "black"
                   :font-weight (when (contains? #{80 120} (+ n mn)) :bold)
                   :text-anchor "start"}
            (+ n mn)])

         [dc/line (- btm-y (* (- 80 mn) scale)) "#33F" 2]
         [dc/line (- btm-y (* (- 120 mn) scale)) "#F33" 2]

         [dc/chart-line2 stats (mapper :bp-systolic) "red" put-fn]
         [dc/chart-line2 stats (mapper :bp-diastolic) "blue" put-fn]

         [dc/line y "#000" 3]
         [dc/line (+ y h) "#000" 3]
         [:rect {:fill :white :x 0 :y y :height (+ h 5) :width 190}]
         (when @show-pvt
           [dc/row-label label y h])]))))
