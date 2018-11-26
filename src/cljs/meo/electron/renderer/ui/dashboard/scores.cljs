(ns meo.electron.renderer.ui.dashboard.scores
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info debug]]
            [reagent.ratom :refer-macros [reaction]]
            [camel-snake-kebab.core :refer [->kebab-case]]
            [meo.electron.renderer.ui.dashboard.common :as dc]
            [clojure.string :as s]
            [meo.common.utils.parse :as up]))

(defn scores-fn [stats k]
  (->> stats
       :questionnaires
       k
       (sort-by first)
       (filter #(seq (second %)))
       (map (fn [[ts m]] (assoc-in m [:timestamp] ts)))))

(defn scatter-chart
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
         [dc/scatter-chart @scores mapper color]
         [dc/line y "#000" 2]
         [dc/line (+ y h) "#000" 2]
         (when @show-pvt
           [dc/row-label label y h])]))))

(defn chart-line [scores point-mapper cfg put-fn]
  (let [active-dashboard (subscribe [:active-dashboard])]
    (fn chart-line-render [scores point-mapper cfg put-fn]
      (let [points (map-indexed point-mapper scores)
            color (:color cfg)
            line-points (s/join " " (map :s points))
            active-dashboard @active-dashboard
            stroke (:stroke_width cfg 1)
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
                                 :stroke-width stroke
                                 :fill         :none}}]])
         [:g
          [:polyline {:points line-points
                      :style  {:stroke       color
                               :stroke-width stroke
                               :fill         :none}}]
          (for [p points]
            ^{:key (str active-dashboard p)}
            [:circle {:cx       (:x p)
                      :cy       (:y p)
                      :on-click (up/add-search (:ts p) :left put-fn)
                      :r        (:circle_radius cfg 3)
                      :fill     (if (:starred p) :white :none)
                      :style    {:stroke       color
                                 :stroke-width (:circle_stroke_width cfg 2)}}])]]))))

(defn scores-chart
  [{:keys []} _put-fn]
  (let [show-pvt (subscribe [:show-pvt])
        gql-res (subscribe [:gql-res])]
    (fn scores-chart-render [{:keys [y k w h score_k start end mn mx
                                     x-offset label] :as cfg} put-fn]
      (let [qid (keyword (str (s/upper-case (name k)) "_" (name score_k)))
            data (sort-by :timestamp
                          (get-in @gql-res [:dashboard-questionnaires :data qid]))
            span (- end start)
            rng (- mx mn)
            scale (/ h rng)
            btm-y (+ y h)
            line-inc (if (> mx 100) 50 10)
            lines (butlast (filter #(zero? (mod % line-inc)) (range 1 rng)))
            mapper (fn [idx itm]
                     (let [ts (:timestamp itm)
                           from-beginning (- ts start)
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
           [dc/line (- btm-y (* n scale)) "#888" 1])
         [chart-line data mapper cfg put-fn]
         [dc/line y "#000" 2]
         [dc/line (+ y h) "#000" 2]
         (when @show-pvt
           [dc/row-label label y h])]))))
