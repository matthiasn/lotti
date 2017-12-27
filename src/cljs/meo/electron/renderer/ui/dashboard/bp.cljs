(ns meo.electron.renderer.ui.dashboard.bp
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.dashboard.common :as dc]
            [clojure.pprint :as pp]))

(defn bp-chart [{:keys []} _put-fn]
  (let []
    (fn bp-chart-render [{:keys [y k score-k h start end mn mx
                                 x-offset label w tag stats]} put-fn]
      (let [span (- end start)
            d (* 24 60 60 1000)
            rng (- mx mn)
            scale (/ h rng)
            btm-y (+ y h)
            line-inc 10
            lines (filter #(zero? (mod % line-inc)) (range 1 rng))
            mapper (fn [k]
                     (fn [idx [ymd v]]
                       (let [offset (* idx d)
                             ts (+ start offset)
                             ymd (dc/df ts dc/ymd)
                             from-beginning (- ts start)
                             x (+ x-offset (* w (/ from-beginning span)))
                             v (get-in stats [ymd tag k] 0)
                             y (- btm-y (* (- v mn) scale))
                             s (str x "," y)]
                         {:ymd ymd
                          :v   v
                          :x   x
                          :y   y
                          :ts  ts
                          :s   s})))]
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

         [dc/line (- btm-y (* (- 80 mn) scale)) "#33F" 1.6]
         [dc/line (- btm-y (* (- 120 mn) scale)) "#F33" 1.6]

         [dc/chart-line stats (mapper :bp-systolic) "red" put-fn]
         [dc/chart-line stats (mapper :bp-diastolic) "blue" put-fn]

         [dc/line y "#000" 2]
         [dc/line (+ y h) "#000" 2]
         [:rect {:fill :white :x 0 :y y :height (+ h 5) :width 190}]
         [dc/row-label label y h]]))))
