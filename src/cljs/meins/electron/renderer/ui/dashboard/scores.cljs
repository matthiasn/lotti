(ns meins.electron.renderer.ui.dashboard.scores
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info debug]]
            [reagent.ratom :refer-macros [reaction]]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [camel-snake-kebab.core :refer [->kebab-case]]
            [meins.electron.renderer.ui.dashboard.common :as dc]
            [clojure.string :as s]
            [meins.common.utils.parse :as up]
            [meins.electron.renderer.helpers :as h]))

(defn scores-fn [stats k]
  (->> stats
       :questionnaires
       k
       (sort-by first)
       (filter #(seq (second %)))
       (map (fn [[ts m]] (assoc-in m [:timestamp] ts)))))

(defn scatter-chart
  [{:keys [k score-k]}]
  (let [stats (subscribe [:stats])
        show-pvt (subscribe [:show-pvt])
        scores (reaction (filter score-k (scores-fn @stats k)))]
    (fn scores-chart-render [{:keys [y k w h score-k start end mn mx color
                                     x-offset label scatter]}]
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
         [dc/scatter-chart @scores mapper color]
         [dc/line y "#000" 2]
         [dc/line (+ y h) "#000" 2]
         [dc/row-label label y h]]))))

(defn chart-line [scores point-mapper cfg start-ymd]
  (let [active-dashboard (subscribe [:active-dashboard])]
    (fn chart-line-render [scores point-mapper cfg start-ymd]
      (let [points (map-indexed point-mapper scores)
            {:keys [color fill glow label]} cfg
            line-points (s/join " " (map :s points))
            active-dashboard @active-dashboard
            stroke (:stroke_width cfg 1)]
        [:g
         (when glow
           [:g {:filter "url(#blur1)"}
            [:rect {:width  "100%"
                    :height "100%"
                    :style  {:fill   :none
                             :stroke :none}}]
            [:polyline {:points line-points
                        :style  {:stroke       color
                                 :stroke-width stroke
                                 :fill         :none}}]])
         [:g
          [:polyline {:points line-points
                      :style  {:stroke       color
                               :stroke-width stroke
                               :fill         :none}}]
          (for [p points]
            [:circle {:cx       (:x p)
                      :cy       (:y p)
                      :id       (str active-dashboard p start-ymd)
                      :on-click (up/add-search
                                  {:tab-group    :left
                                   :first-line   label
                                   :query-string (:ts p)} emit)
                      :r        (:circle_radius cfg 3)
                      :fill     fill
                      :style    {:stroke       color
                                 :stroke-width (:circle_stroke_width cfg 3)}}])]]))))

(defn scores-chart
  [{:keys []}]
  (let [dashboard-data (subscribe [:dashboard-data])]
    (fn scores-chart-render [{:keys [y k w h score_k start end mn mx offset
                                     x-offset label tag] :as cfg}]
      (let [start-ymd (h/ymd start)
            end-ymd (h/ymd end)
            data (->> @dashboard-data
                      (filter #(<= start-ymd (first %)))
                      (filter #(> end-ymd (first %)))
                      (map second)
                      (mapcat #(get-in % [:questionnaires tag (name score_k)]))
                      (sort-by :timestamp)
                      (filter #(< (:timestamp %) end))
                      (filter #(> (:timestamp %) start)))
            span (- end start)
            line-inc 5
            rng (- mx mn)
            scale (/ h rng)
            btm-y (+ y h)
            lines (filter #(zero? (mod % line-inc)) (range mn mx))
            mapper (fn [idx itm]
                     (let [ts (:timestamp itm)
                           offset (* offset (* 24 60 60 1000))
                           from-beginning (- ts start offset)
                           x (+ x-offset (* w (/ from-beginning span)))
                           v (:score itm)
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
           ^{:key (str k score_k n)}
           [dc/line (- btm-y (* (- n mn) scale)) "#888" 1])
         (for [n lines]
           ^{:key (str score_k k n)}
           [:text {:x           624
                   :y           (- (+ btm-y 5) (* (- n mn) scale))
                   :font-size   11
                   :fill        "black"
                   :text-anchor "start"}
            n])
         [chart-line data mapper cfg start-ymd]
         [dc/line y "#000" 2]
         [dc/line (+ y h) "#000" 2]
         [dc/row-label label y h]]))))
