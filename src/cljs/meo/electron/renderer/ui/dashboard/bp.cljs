(ns meo.electron.renderer.ui.dashboard.bp
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info debug]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.dashboard.common :as dc]
            [meo.common.utils.parse :as up]
            [clojure.string :as s]))

(defn chart-line [scores point-mapper cfg put-fn]
  (let [active-dashboard (subscribe [:active-dashboard])]
    (fn chart-line-render [scores point-mapper cfg put-fn]
      (let [color (:color cfg)
            points (map-indexed point-mapper scores)
            points (filter #(pos? (:v %)) (apply concat points))
            points (sort-by :ts points)
            line-points (s/join " " (map :s points))
            active-dashboard @active-dashboard
            glow (:glow cfg)]
        [:g
         (when glow
           [:g {:filter "url(#blur1)"}
            [:rect {:width  "100%"
                    :height "100%"
                    :style  {:fill   :none
                             :stroke :none}}]
            [:polyline {:points line-points
                        :style  {:stroke       color
                                 :stroke-width (:stroke_width cfg 1.5)
                                 :fill         :none}}]])
         [:g
          [:polyline {:points line-points
                      :style  {:stroke       color
                               :stroke-width (:stroke_width cfg 1.5)
                               :fill         :none}}]
          (for [p points]
            ^{:key (str active-dashboard p)}
            [:circle {:cx       (:x p)
                      :cy       (:y p)
                      :on-click (up/add-search (:ts p) :right put-fn)
                      :fill     :none
                      :r        (:circle_radius cfg 3)
                      :style    {:stroke       color
                                 :stroke-width (:circle_stroke_width cfg 2)}}])]]))))

(defn bp-chart [_ _put-fn]
  (let [show-pvt (subscribe [:show-pvt])
        gql-res (subscribe [:gql-res])
        bp-data (reaction (get-in @gql-res [:bp :data :bp_field_stats]))]
    (fn [{:keys [y k h start span mn mx x-offset w stroke_width] :as m} put-fn]
      (debug :bp-chart m)
      (let [mx (or mx 200)
            mn (or mn 200)
            w (or w 500)
            rng (- mx mn)
            label "Blood Pressure"
            scale (/ h rng)
            btm-y (+ y h)
            line-inc 10
            lines (filter #(zero? (mod % line-inc)) (range 1 rng))
            mapper (fn [k]
                     (fn [idx data]
                       (let [ts (:timestamp data)
                             v (get data k)
                             from-beginning (- ts start)
                             x (+ x-offset
                                  (* w (/ from-beginning span)))
                             y (- btm-y (* (- v mn) scale))
                             s (str x "," y)]
                         [{:v  v
                           :x  x
                           :y  y
                           :ts ts
                           :s  s}])))]
        [:g
         (for [n lines]
           ^{:key (str "bp" k n)}
           [dc/line (- btm-y (* n scale)) "#888" 1])
         (for [n lines]
           ^{:key (str "bp" k n)}
           [:text {:x           2008
                   :y           (- (+ btm-y 5) (* n scale))
                   :font-size   8
                   :fill        "black"
                   :font-weight (when (contains? #{80 120} (+ n mn)) :bold)
                   :text-anchor "start"}
            (+ n mn)])

         [dc/line (- btm-y (* (- 80 mn) scale)) "#33F" 2]
         [dc/line (- btm-y (* (- 120 mn) scale)) "#F33" 2]

         [chart-line @bp-data (mapper :bp_systolic) (merge {:color "red"} m) put-fn]
         [chart-line @bp-data (mapper :bp_diastolic) (merge {:color "blue"} m) put-fn]

         [dc/line y "#000" 3]
         [dc/line (+ y h) "#000" 3]
         [dc/row-label label y h]]))))
