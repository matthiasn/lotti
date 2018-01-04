(ns meo.electron.renderer.ui.dashboard.common
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.helpers :as h]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]
            [clojure.pprint :as pp]
            [clojure.string :as s]
            [meo.electron.renderer.ui.charts.common :as cc]
            [meo.common.utils.parse :as up]))

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

(defn chart-line [scores point-mapper color put-fn]
  (let [active-dashboard (subscribe [:active-dashboard])]
    (fn chart-line-render [scores point-mapper color put-fn]
      (let [points (map-indexed point-mapper scores)
            line-points (s/join " " (map :s points))
            active-dashboard @active-dashboard]
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
            ^{:key (str active-dashboard p)}
            [:circle {:cx       (:x p)
                      :cy       (:y p)
                      :on-click (up/add-search (:ts p) :right put-fn)
                      :r        (if (:starred p) 5 2.5)
                      :fill     (if (:starred p) :white :none)
                      :style    {:stroke color}}])]]))))

(defn chart-line2 [scores point-mapper color put-fn]
  (let [active-dashboard (subscribe [:active-dashboard])]
    (fn chart-line-render [scores point-mapper color put-fn]
      (let [points (map-indexed point-mapper scores)
            points (filter #(pos? (:v %)) (apply concat points))
            points (sort-by :ts points)
            line-points (s/join " " (map :s points))
            active-dashboard @active-dashboard]
        [:g
         [:g {:filter "url(#blur1)"}
          [:rect {:width  "100%"
                  :height "100%"
                  :style  {:fill   :none
                           :stroke :none}}]
          [:polyline {:points line-points
                      :style  {:stroke       color
                               :stroke-width 1.5
                               :fill         :none}}]]
         [:g
          [:polyline {:points line-points
                      :style  {:stroke       color
                               :stroke-width 2
                               :fill         :none}}]
          (for [p points]
            ^{:key (str active-dashboard p)}
            [:circle {:cx       (:x p)
                      :cy       (:y p)
                      :on-click (up/add-search (:ts p) :right put-fn)
                      :r        (if (:starred p) 8 2)
                      :fill     (if (:starred p) :white :none)
                      :style    {:stroke color}}])]]))))

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

(defn rect [{:keys [v x w y h cls n]}]
  (let [local (r/atom {})
        click (fn [_] (swap! local update-in [:show-label] not))]
    (fn [{:keys [v x w y h cls n]}]
      [:g
       [:rect {:on-click click
               :x        x
               :y        (- y h)
               :width    w
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
                                 [n {:ymd       ymd
                                     :v         v
                                     :timestamp ts
                                     :weekday   weekday}]))
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

(defn barchart-row [{:keys [days span mx label start stats tag k h y cls]} put-fn]
  (let [btm-y (+ y h)
        indexed (indexed-days stats tag k start days)
        mx (or mx (apply max (map #(:v (second %)) indexed)))
        scale (if (pos? mx) (/ (- h 3) mx) 1)]
    [:g
     [row-label (or label tag) y h]
     (for [[n {:keys [ymd v weekday]}] indexed]
       (let [d (* 24 60 60 1000)
             offset (* n d)
             span (if (zero? span) 1 span)
             scaled (* 1800 (/ offset span))
             x (+ 202 scaled)
             v (min mx v)
             h (* v scale)
             weekend? (get #{"Sat" "Sun"} weekday)
             display-v (if (= :duration k)
                         (h/m-to-hh-mm v)
                         v)]
         ^{:key (str tag k n)}
         [rect {:v   display-v
                :x   x
                :w   14
                :y   btm-y
                :h   h
                :cls cls
                :n   n}]))
     [line (+ y h) "#000" 2]]))

(defn points-by-day-chart [{:keys [y h label span]}]
  (let [stats (subscribe [:stats])]
    (fn points-by-day-render [{:keys [y h label]}]
      (let [btm-y (+ y h)
            award-points (:award-points @stats)
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
               [:rect {:x      (+ 202 (* 20 idx))
                       :y      (- btm-y h)
                       :fill   "#7FE283"
                       :width  14
                       :height h}])))
         (for [[idx [day v]] indexed]
           (let [v (:task v)
                 y-scale (/ h (or max-val 1))
                 h (if (pos? v) (* y-scale v) 0)]
             (when (pos? max-val)
               ^{:key (str day idx)}
               [:rect {:x      (+ 202 (* 20 idx))
                       :y      (- btm-y h)
                       :fill   "#42b8dd"
                       :width  14
                       :height h}])))
         [line (+ y h) "#000" 2]
         [row-label label y h]]))))

(defn points-lost-by-day-chart [{:keys [y h label]}]
  (let [stats (subscribe [:stats])]
    (fn points-by-day-render [{:keys [y h label]}]
      (let [btm-y (+ y h)
            award-points (:award-points @stats)
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
