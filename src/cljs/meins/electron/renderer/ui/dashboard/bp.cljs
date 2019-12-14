(ns meins.electron.renderer.ui.dashboard.bp
  (:require [clojure.string :as s]
            [meins.common.utils.parse :as up]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.dashboard.common :as dc]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer [debug info]]))

(defn line [y s w]
  [:line {:x1           200
          :x2           620
          :y1           y
          :y2           y
          :stroke-width w
          :stroke       s}])

(defn chart-line [_ _ _]
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
            (let [bp_systolic (-> p :data first :v)
                  bp_diastolic (-> p :data second :v)
                  ymd (h/ymd (:ts p))
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
                                          {:tab-group    :left
                                           :first-line   (str "#BP " bp)
                                           :query-string (:ts p)} emit)
                        :fill           fill
                        :r              (:circle_radius cfg 3)
                        :style          {:stroke       color
                                         :stroke-width (:circle_stroke_width cfg 2)}}]))]]))))

(defn fields [field data]
  (->> data
       (mapcat identity)
       (filter #(seq (:values %)))
       (filter #(= (name field) (:field %)))
       (map :values)
       (mapcat identity)))

(defn bp-chart [_]
  (let [pvt (subscribe [:show-pvt])
        dashboard-data (subscribe [:dashboard-data])]
    (fn [{:keys [y k h start end span mn mx x-offset w systolic_color systolic_fill
                 diastolic_color diastolic_fill] :as m}]
      (let [mx (or mx 200)
            mn (or mn 50)
            w (or w 500)
            rng (- mx mn)
            label "Blood Pressure"
            scale (/ h rng)
            btm-y (+ y h)
            line-inc 10
            systolic-cfg (merge {:color (or systolic_color "red")
                                 :fill  (or systolic_fill "red")}
                                m)
            diastolic-cfg (merge {:color (or diastolic_color "blue")
                                  :fill  (or diastolic_fill "blue")}
                                 m)
            lines (filter #(zero? (mod % line-inc)) (range 1 rng))
            start-ymd (h/ymd start)
            end-ymd (h/ymd end)
            data (->> @dashboard-data
                      (filter #(< start-ymd (first %)))
                      (filter #(> end-ymd (first %)))
                      (map second)
                      (map #(get-in % [:custom-fields "#BP"]))
                      (map :fields))
            systolic (fields "bp_systolic" data)
            diastolic (fields "bp_diastolic" data)
            values (map vector systolic diastolic)
            mapper (fn [pos _idx both]
                      (let [data (pos both)
                            ts (:ts data)
                            v (:v data)
                            from-beginning (- ts start)
                            x (+ x-offset
                                 (* w (/ from-beginning span)))
                            y (- btm-y (* (- v mn) scale))
                            s (str x "," y)]
                        [{:v    v
                          :data both
                          :x    x
                          :y    y
                          :ts   ts
                          :s    s}]))]
        [:g
         (for [n lines]
           ^{:key (str "bp" k n)}
           [dc/line (- btm-y (* n scale)) "#888" 1])
         (when @pvt
           (for [n lines]
             ^{:key (str "bp" k n)}
             [:text {:x           624
                     :y           (- (+ btm-y 5) (* n scale))
                     :font-size   11
                     :fill        "black"
                     :font-weight (when (contains? #{80 120} (+ n mn)) :bold)
                     :text-anchor "start"}
              (+ n mn)]))

         [line (- btm-y (* (- 80 mn) scale)) :black 1]
         [line (- btm-y (* (- 120 mn) scale)) :black 1]

         [chart-line values (partial mapper first) systolic-cfg]
         [chart-line values (partial mapper second) diastolic-cfg]

         [dc/line y "#000" 3]
         [dc/line (+ y h) "#000" 3]
         [dc/row-label label y h]]))))
