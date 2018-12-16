(ns meo.electron.renderer.ui.dashboard.cf-linechart
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]
            [taoensso.timbre :refer-macros [info debug]]
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

(defn row-label [label y h]
  [:text {:x           180
          :y           (+ y (+ 5 (/ h 2)))
          :font-size   20
          :fill        "#777"
          :text-anchor "end"}
   label])

(defn chart-line [scores point-mapper cfg]
  (let [active-dashboard (subscribe [:active-dashboard])]
    (fn chart-line-render [scores point-mapper cfg]
      (let [{:keys [color label local fill]} cfg
            points (map-indexed point-mapper scores)
            points (filter #(pos? (:v %)) (apply concat points))
            points (sort-by :ts points)
            line-points (s/join " " (map :s points))
            active-dashboard @active-dashboard]
        [:g
         [:polyline {:points line-points
                     :style  {:stroke       color
                              :stroke-width (:stroke_width cfg 3)
                              :fill         :none}}]
         (for [p points]
           (let [enter #(let [ymd (df (:ts p) ymd)
                              t [:span ymd ": " [:strong (:v p)] " " label]]
                          (swap! local assoc :display-text t))
                 leave #(swap! local assoc :display-text "")]
             ^{:key (str active-dashboard p)}
             [:circle {:cx             (:x p)
                       :cy             (:y p)
                       :on-mouse-enter enter
                       :on-mouse-leave leave
                       :fill           fill
                       :r              (:circle_radius cfg 4)
                       :style          {:stroke       color
                                        :stroke-width (:circle_stroke_width cfg 2)}}]))]))))

(defn linechart-row [_ _]
  (let [gql-res (subscribe [:gql-res])
        backend-cfg (subscribe [:backend-cfg])
        custom-fields (reaction (:custom-fields @backend-cfg))]
    (fn linechart-row-render
      [{:keys [span start x-offset w tag h y field] :as m} _]
      (when (and tag field (seq tag))
        (let [btm-y (+ y h)
              qid (keyword (s/replace (subs (str tag) 1) "-" "_"))
              data (get-in @gql-res [:dashboard :data qid])
              label (get-in @custom-fields [tag :fields (keyword field) :label])
              values (->> data
                          (map :fields)
                          (mapcat identity)
                          (filter #(seq (:values %)))
                          (filter #(= (name field) (:field %)))
                          (map :values)
                          (mapcat identity))
              mn (apply min (map :v values))
              mn (- mn (mod mn 5) 5)
              mx (apply max (map :v values))
              mx (+ (- mx (mod mx 5)) 10)
              range (- mx mn)
              scale (if (pos? mx) (/ (- h 3) range) 1)
              mapper (fn [idx data]
                       (let [ts (:ts data)
                             v (:v data)
                             from-beginning (- ts start)
                             x (+ x-offset
                                  (* w (/ from-beginning span)))
                             y (- btm-y (* (- v mn) scale))
                             s (str x "," y)]
                         [{:v  v
                           :x  x
                           :y  y
                           :ts ts
                           :s  s}]))
              cfg (merge m {:label label})]
          [:g
           [row-label (or label tag) y h]
           [chart-line values mapper (merge {:color "red"} cfg)]
           [line (+ y h) "#000" 2]])))))
