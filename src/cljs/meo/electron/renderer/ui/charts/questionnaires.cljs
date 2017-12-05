(ns meo.electron.renderer.ui.charts.questionnaires
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.helpers :as h]
            [reagent.ratom :refer-macros [reaction]]
            [goog.string :as gstring]
            [reagent.core :as r]
            [clojure.pprint :as pp]
            [clojure.string :as s]
            [matthiasn.systems-toolbox.component :as st]
            [meo.electron.renderer.ui.charts.common :as cc]))

(def month-day "DD.MM.")
(def ymd "YYYY-MM-DD")
(def weekday "ddd")
(defn df [ts format] (.format (moment ts) format))

(def tz-offset
  (-> (js/Date.)
      (.getTimezoneOffset)
      (* 60 1000)))

(defn tick
  "Renders individual timeline tick."
  [pos color w y1 y2]
  [:line {:x1           pos
          :y1           y1
          :x2           pos
          :y2           y2
          :stroke       color
          :stroke-width w}])

(defn chart-line [scores point-mapper color]
  (let [points (map-indexed point-mapper scores)
        line-points (s/join " " (map :s points))]
    [:g
     [:g {:filter "url(#blur1)"}
      [:rect {:width  "100%"
              :height "100%"
              :style  {:fill   :none
                       :stroke :none}}]
      [:polyline {:points line-points
                  :style  {:stroke       color
                           :stroke-width 2
                           :fill         :none}}]]
     [:g
      [:polyline {:points line-points
                  :style  {:stroke       color
                           :stroke-width 1
                           :fill         :none}}]
      (for [p points]
        ^{:key (str p)}
        [:circle {:cx    (:x p)
                  :cy    (:y p)
                  :r     1.6
                  :fill  :none
                  :style {:stroke color}}])]]))

(defn scatter-chart [scores point-mapper color]
  (let [points (map-indexed point-mapper scores)]
    [:g
     (for [p points]
       ^{:key (str p)}
       [:circle {:cx    (:x p)
                 :cy    (:y p)
                 :r     1.6
                 :style {:stroke  color
                         :fill    color
                         :opacity 0.6}}])]))

(defn line [y s w]
  [:line {:x1           195
          :x2           2000
          :y1           y
          :y2           y
          :stroke-width w
          :stroke       s}])

(defn rect [v x y h cls n]
  (let [local (r/atom {})
        click (fn [_] (swap! local update-in [:show-label] not))]
    (fn [v x y h cls n]
      [:g
       [:rect {:on-click click
               :x        x
               :y        (- y h)
               :width    6
               :height   h
               :class    (cc/weekend-class cls ymd)}]
       (when (:show-label @local)
         [:text {:x           (+ x 11)
                 :y           (- y 5)
                 :font-size   8
                 :fill        "#777"
                 :text-anchor "middle"}
          v])])))

(defn indexed-days [stats tag k start days]
  (let [d (* 24 60 60 1000)
        rng (range (inc days))
        indexed (map-indexed (fn [n v]
                               (let [offset (* n d)
                                     ts (+ start offset)
                                     ymd (df ts ymd)
                                     v (get-in stats [ymd tag k] 0)
                                     weekday (df ts weekday)]
                                 [n {:ymd     ymd
                                     :v       v
                                     :weekday weekday}]))
                             rng)]
    indexed))

(defn indexed-days2 [stats k start days]
  (let [d (* 24 60 60 1000)
        rng (range (inc days))
        indexed (map-indexed (fn [n v]
                               (let [offset (* n d)
                                     ts (+ start offset)
                                     ymd (df ts ymd)
                                     v (get-in stats [ymd k] 0)
                                     weekday (df ts weekday)]
                                 [n {:ymd     ymd
                                     :v       v
                                     :weekday weekday}]))
                             rng)]
    indexed))

(defn row-label [label y h]
  [:text {:x           180
          :y           (+ y (+ 5 (/ h 2)))
          :font-size   12
          :fill        "#777"
          :font-weight :bold
          :text-anchor "end"}
   label])

(defn barchart-row [{:keys [days span start stats tag k h y cls]}]
  (let [btm-y (+ y h)
        indexed (indexed-days stats tag k start days)
        mx (apply max (map #(:v (second %)) indexed))
        scale (if (pos? mx) (/ (- h 3) mx) 1)]
    [:g
     [row-label tag y h]
     (for [[n {:keys [ymd v weekday]}] indexed]
       (let [d (* 24 60 60 1000)
             offset (* n d)
             span (if (zero? span) 1 span)
             scaled (* 1800 (/ offset span))
             x (+ 202 scaled)
             h (* v scale)
             weekend? (get #{"Sat" "Sun"} weekday)
             display-v (if (= :duration k)
                         (h/m-to-hh-mm v)
                         v)]
         ^{:key (str tag n)}
         [rect display-v x btm-y h cls n]))
     [line (+ y h) "#000" 2]]))

(defn chart-data-row [{:keys [days span start chart-data data-k label k h y cls]}]
  (let [btm-y (+ y h)
        stats (data-k chart-data)
        indexed (indexed-days2 stats k start days)
        mx (apply max (map #(:v (second %)) indexed))
        scale (if (pos? mx) (/ (- h 3) mx) 1)]
    [:g
     [row-label label y h]
     (for [[n {:keys [ymd v weekday]}] indexed]
       (let [d (* 24 60 60 1000)
             offset (* n d)
             span (if (zero? span) 1 span)
             scaled (* 1800 (/ offset span))
             x (+ 203 scaled)
             h (* v scale)
             weekend? (get #{"Sat" "Sun"} weekday)
             display-v (if (= :duration k)
                         (h/m-to-hh-mm v)
                         v)]
         ^{:key (str label n)}
         [rect display-v x btm-y h cls n]))
     [line (+ y h) "#000" 2]]))

(defn points-by-day-chart [{:keys [y h label span]}]
  (let [stats (subscribe [:stats])
        btm-y (+ y h)]
    (fn points-by-day-render [{:keys [y h label]}]
      (let [award-points (:award-points @stats)
            by-day (sort-by first (:by-day award-points))
            daily-totals (map (fn [[d v]] (h/add (:task v) (:habit v))) by-day)
            max-val (apply max daily-totals)
            indexed (map-indexed (fn [idx [day v]] [idx [day v]])
                                 (take-last 180 by-day))]
        [:g
         (for [[idx [day v]] indexed]
           (let [v (h/add (:task v) (:habit v))
                 y-scale (/ h (or max-val 1))
                 h (if (pos? v) (* y-scale v) 0)]
             (when (pos? max-val)
               ^{:key (str day idx)}
               [:rect {:x      (+ 202 (* 10 idx))
                       :y      (- btm-y h)
                       :fill   "#7FE283"
                       :width  6
                       :height h}])))
         (for [[idx [day v]] indexed]
           (let [v (:task v)
                 y-scale (/ h (or max-val 1))
                 h (if (pos? v) (* y-scale v) 0)]
             (when (pos? max-val)
               ^{:key (str day idx)}
               [:rect {:x      (+ 202 (* 10 idx))
                       :y      (- btm-y h)
                       :fill   "#42b8dd"
                       :width  6
                       :height h}])))
         [line (+ y h) "#000" 2]
         [row-label label y h]]))))

(defn points-lost-by-day-chart [{:keys [y h label]}]
  (let [stats (subscribe [:stats])
        btm-y (+ y h)]
    (fn points-by-day-render [{:keys [y h label]}]
      (let [award-points (:award-points @stats)
            by-day (sort-by first (:by-day-skipped award-points))
            daily-totals (map (fn [[d v]] (:habit v)) by-day)
            max-val (apply max daily-totals)
            indexed (map-indexed (fn [idx [day v]] [idx [day v]])
                                 (take-last 180 by-day))]
        [:g
         (for [[idx [day v]] indexed]
           (let [v (:habit v)
                 y-scale (/ h (or max-val 1))
                 h (if (pos? v) (* y-scale v) 0)]
             (when (pos? max-val)
               ^{:key (str day idx)}
               [:rect {:x      (+ 202 (* 10 idx))
                       :y      (- btm-y h)
                       :fill   "#f3b3b3"
                       :width  6
                       :height h}])))
         [line (+ y h) "#000" 2]
         [row-label label y h]]))))

(defn scores-fn [stats k]
  (->> stats
       :questionnaires
       k
       (sort-by first)
       (filter #(seq (second %)))
       (map (fn [[ts m]] (assoc-in m [:timestamp] ts)))))

(defn scores-chart
  [{:keys [y k w h score-k start end mn mx color x-offset label scatter]}]
  (let [stats (subscribe [:stats])
        scores (reaction (filter score-k (scores-fn @stats k)))
        span (- end start)
        rng (- mx mn)
        scale (/ h rng)
        btm-y (+ y h)
        mapper (fn [idx itm]
                 (let [ts (:timestamp itm)
                       from-beginning (- ts start)
                       x (+ x-offset (* w (/ from-beginning span)))
                       y (- btm-y (* (- (score-k itm) mn) scale))
                       s (str x "," y)]
                   {:x x
                    :y y
                    :s s}))
        line-inc (if (> mx 100) 50 10)
        lines (filter #(zero? (mod % line-inc)) (range 1 rng))]
    (fn scores-chart-render [{:keys [y k score-k start end mn mx color]}]
      [:g
       (for [n lines]
         ^{:key (str k score-k n)}
         [line (- btm-y (* n scale)) "#888" 1])
       (if scatter
         [scatter-chart @scores mapper color]
         [chart-line @scores mapper color])
       [line y "#000" 2]
       [line (+ y h) "#000" 2]
       [:rect {:fill :white :x 0 :y y :height (+ h 5) :width 190}]
       [row-label label y h]])))

(defn charts-y-pos [cfg]
  (reduce
    (fn [acc m]
      (let [{:keys [last-y last-h]} acc
            cfg (assoc-in m [:y] (+ last-y last-h))]
        {:last-y (:y cfg)
         :last-h (:h cfg)
         :charts (conj (:charts acc) cfg)}))
    {:last-y 50
     :last-h 0}
    cfg))

(defn dashboard [put-fn dashboard-id]
  (let [custom-field-stats (subscribe [:custom-field-stats])
        chart-data (subscribe [:chart-data])
        current-page (subscribe [:current-page])
        last-update (subscribe [:last-update])
        options (subscribe [:options])
        questionnaires (reaction (:questionnaires @options))
        local (r/atom {:n 180})]
    (h/keep-updated :stats/custom-fields 180 local 0 put-fn)
    (h/keep-updated :stats/wordcount 180 local 0 put-fn)
    (fn dashboard-render [put-fn dashboard-id]
      (h/keep-updated :stats/custom-fields 180 local @last-update put-fn)
      (h/keep-updated :stats/wordcount 180 local @last-update put-fn)
      (let [days (:n @local)
            dashboard-id (or dashboard-id (keyword (:id @current-page)))
            now (st/now)
            d (* 24 60 60 1000)
            within-day (mod now d)
            start (+ tz-offset (- now within-day (* days d)))
            end (+ (- now within-day) d tz-offset)
            span (- end start)
            custom-field-stats @custom-field-stats
            common {:start      start :end end :w 1800 :x-offset 200
                    :span       span :days days :stats custom-field-stats
                    :chart-data @chart-data}
            charts-cfg (get-in @questionnaires [:dashboards dashboard-id])
            positioned-charts (charts-y-pos charts-cfg)
            end-y (+ (:last-y positioned-charts) (:last-h positioned-charts))]
        [:div.questionnaires
         [:svg {:viewBox "0 0 2100 1600"
                :style   {:background :white}}
          [:filter#blur1
           [:feGaussianBlur {:stdDeviation 3}]]
          [:g
           (for [n (range (+ 2 days))]
             (let [offset (+ (* n d) tz-offset)
                   scaled (* 1800 (/ offset span))
                   x (+ 200 scaled)]
               ^{:key n}
               [tick x "#CCC" 1 30 end-y]))]
          (for [chart-cfg (:charts positioned-charts)]
            (let [chart-fn (case (:type chart-cfg)
                             :scores-chart scores-chart
                             :barchart-row barchart-row
                             :chart-data-row chart-data-row
                             :points-by-day points-by-day-chart
                             :points-lost-by-day points-lost-by-day-chart)]
              ^{:key (str (:label chart-cfg) (:tag chart-cfg))}
              [chart-fn (merge common chart-cfg)]))
          (for [n (range (inc days))]
            (let [offset (+ (* (+ n 0.5) d) tz-offset)
                  scaled (* 1800 (/ offset span))
                  x (+ 200 scaled)
                  ts (+ start offset)
                  weekday (df ts weekday)
                  weekend? (get #{"Sat" "Sun"} weekday)]
              ^{:key n}
              [:g {:writing-mode "tb-rl"}
               [:text {:x           x
                       :y           40
                       :font-size   6
                       :fill        (if weekend? :red :black)
                       :font-weight :bold
                       :text-anchor "middle"}
                (df ts month-day)]]))]]))))
