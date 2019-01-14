(ns meins.electron.renderer.ui.dashboard.bp
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info debug]]
            [reagent.ratom :refer-macros [reaction]]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.dashboard.common :as dc]
            [meins.common.utils.parse :as up]
            [clojure.string :as s]))

(def ymd "YYYY-MM-DD")
(defn df [ts format] (.format (moment ts) format))

(defn line [y s w]
  [:line {:x1           195
          :x2           2000
          :y1           y
          :y2           y
          :stroke-width w
          :stroke       s}])

(defn chart-line [scores point-mapper cfg]
  (let [active-dashboard (subscribe [:active-dashboard])]
    (fn chart-line-render [scores point-mapper cfg]
      (let [{:keys [color fill glow local]} cfg
            points (map-indexed point-mapper scores)
            points (filter #(pos? (:v %)) (apply concat points))
            points (sort-by :ts points)
            fill (or fill color)
            line-points (s/join " " (map :s points))
            active-dashboard @active-dashboard]
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
            (let [{:keys [bp_systolic bp_diastolic]} (:data p)
                  ymd (df (:ts p) ymd)
                  bp (str bp_systolic "/" bp_diastolic " mmHG")
                  t [:span ymd ": " [:strong bp]]
                  enter #(swap! local assoc :display-text t)
                  leave #(swap! local assoc :display-text "")]
              ^{:key (str active-dashboard p)}
              [:circle {:cx             (:x p)
                        :cy             (:y p)
                        :on-mouse-enter enter
                        :on-mouse-leave leave
                        :on-click       (up/add-search
                                          {:tab-group    :right
                                           :first-line   (str "#BP " bp)
                                           :query-string (:ts p)} emit)
                        :fill           fill
                        :r              (:circle_radius cfg 3)
                        :style          {:stroke       color
                                         :stroke-width (:circle_stroke_width cfg 2)}}]))]]))))

(defn bp-chart [_]
  (let [pvt (subscribe [:show-pvt])
        gql-res (subscribe [:gql-res])
        bp-data (reaction (get-in @gql-res [:bp :data :bp_field_stats]))]
    (fn [{:keys [y k h start span mn mx x-offset w systolic_color systolic_fill
                 diastolic_color diastolic_fill] :as m}]
      (debug :bp-chart m)
      (let [mx (or mx 200)
            mn (or mn 50)
            w (or w 500)
            rng (- mx mn)
            label "Blood Pressure"
            scale (/ h rng)
            btm-y (+ y h)
            line-inc 10
            systolic-cfg (merge {:color (or systolic_color "red") :fill
                                        (or systolic_fill "red")} m)
            diastolic-cfg (merge {:color (or diastolic_color "blue") :fill
                                         (or diastolic_fill "blue")} m)
            lines (filter #(zero? (mod % line-inc)) (range 1 rng))
            mapper (fn [k]
                     (fn [idx data]
                       (let [ts (or (:adjusted_ts data)
                                    (:timestamp data))
                             v (get data k)
                             from-beginning (- ts start)
                             x (+ x-offset
                                  (* w (/ from-beginning span)))
                             y (- btm-y (* (- v mn) scale))
                             s (str x "," y)]
                         [{:v    v
                           :data data
                           :x    x
                           :y    y
                           :ts   ts
                           :s    s}])))]
        [:g
         (for [n lines]
           ^{:key (str "bp" k n)}
           [dc/line (- btm-y (* n scale)) "#888" 1])
         (when @pvt
           (for [n lines]
             ^{:key (str "bp" k n)}
             [:text {:x           2008
                     :y           (- (+ btm-y 5) (* n scale))
                     :font-size   10
                     :fill        "black"
                     :font-weight (when (contains? #{80 120} (+ n mn)) :bold)
                     :text-anchor "start"}
              (+ n mn)]))

         [line (- btm-y (* (- 80 mn) scale)) :black 1]
         [line (- btm-y (* (- 120 mn) scale)) :black 1]

         [chart-line @bp-data (mapper :bp_systolic) systolic-cfg ]
         [chart-line @bp-data (mapper :bp_diastolic) diastolic-cfg ]

         [dc/line y "#000" 3]
         [dc/line (+ y h) "#000" 3]
         [dc/row-label label y h]]))))
