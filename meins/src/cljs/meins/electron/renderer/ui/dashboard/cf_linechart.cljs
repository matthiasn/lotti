(ns meins.electron.renderer.ui.dashboard.cf-linechart
  (:require [clojure.string :as s]
            [meins.common.utils.parse :as up]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.dashboard.common :as dc]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug info]]))

(defn chart-line [_ _ _]
  (let [active-dashboard (subscribe [:active-dashboard])]
    (fn chart-line-render [scores point-mapper cfg]
      (let [{:keys [color label local fill tag]} cfg
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
           (let [ymd (h/ymd (:ts p))
                 enter #(let [t [:span ymd ": " [:strong (:v p)] " " label]]
                          (swap! local assoc :display-text t))
                 click #(let [q (merge (up/parse-search tag)
                                       {:from ymd
                                        :to   ymd})]
                          (emit [:search/add {:tab-group :right
                                              :query     q}]))
                 leave #(swap! local assoc :display-text "")]
             ^{:key (str active-dashboard p)}
             [:circle {:cx             (:x p)
                       :cy             (:y p)
                       :on-mouse-enter enter
                       :on-mouse-leave leave
                       :on-click       click
                       :fill           fill
                       :r              (:circle_radius cfg 4)
                       :style          {:stroke       color
                                        :stroke-width (:circle_stroke_width cfg 2)}}]))]))))

(defn linechart-row [_]
  (let [dashboard-data (subscribe [:dashboard-data])
        pvt (subscribe [:show-pvt])
        backend-cfg (subscribe [:backend-cfg])
        custom-fields (reaction (:custom-fields @backend-cfg))]
    (fn linechart-row-render
      [{:keys [span start end x-offset w tag h y field] :as m}]
      (when (and tag field (seq tag))
        (let [btm-y (+ y h)
              qid (keyword (s/replace (subs (str tag) 1) "-" "_"))
              start-ymd (h/ymd start)
              end-ymd (h/ymd end)
              data (->> @dashboard-data
                        (filter #(< start-ymd (first %)))
                        (filter #(> end-ymd (first %)))
                        (map second)
                        (map #(get-in % [:custom-fields tag])))
              label (get-in @custom-fields [tag :fields (keyword field) :label])
              values (->> data
                          (map :fields)
                          (mapcat identity)
                          (filter #(seq (:values %)))
                          (filter #(= (name field) (:field %)))
                          (map :values)
                          (mapcat identity))
              values (->> values
                          (filter #(< (:ts %) end))
                          (filter #(> (:ts %) start)))
              mn (if (seq values) (apply min (map :v values)) 0)
              mx (apply max 1 (map :v values))
              rng (- mx mn)
              line-inc (cond
                         (> rng 2000) 1000
                         (> rng 1000) 500
                         (> rng 500) 250
                         (> rng 180) 100
                         (> rng 90) 50
                         (> rng 30) 20
                         (> rng 15) 10
                         (> rng 5) 5
                         :else 1)
              mn (- mn (mod mn line-inc))
              mx (+ (- mx (mod mx line-inc)) line-inc)
              rng (- mx mn)
              scale (if (pos? mx) (/ (- h 3) rng) 1)
              lines (filter #(zero? (mod % line-inc)) (range 1 rng))
              mapper (fn [_idx data]
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
           [dc/row-label (or label tag) y h]
           (for [n lines]
             ^{:key (str qid n)}
             [dc/line (- btm-y (* n scale)) "#888" 1])
           (when @pvt
             (for [n lines]
               ^{:key (str qid n)}
               [:text {:x           624
                       :y           (- (+ btm-y 5) (* n scale))
                       :font-size   11
                       :fill        "black"
                       :text-anchor "start"}
                (+ mn n)]))
           [chart-line values mapper (merge {:color "red"} cfg)]
           [dc/line (+ y h) "#000" 2]])))))
