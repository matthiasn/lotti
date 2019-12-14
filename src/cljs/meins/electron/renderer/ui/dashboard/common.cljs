(ns meins.electron.renderer.ui.dashboard.common
  (:require ["moment" :as moment]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug info]]))

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

(defn scatter-chart [scores point-mapper color]
  (let [points (map-indexed point-mapper scores)]
    [:g
     (for [p points]
       ^{:key (str p)}
       [:circle {:cx    (:x p)
                 :cy    (:y p)
                 :r     3.2
                 :style {:stroke  color
                         :fill    color
                         :opacity 0.5}}])]))

(defn line [y s w]
  [:line {:x1           200
          :x2           620
          :y1           y
          :y2           y
          :stroke-width w
          :stroke       s}])

(defn row-label [label y h]
  [:text {:x           185
          :y           (+ y (+ 8 (/ h 2)))
          :font-size   22
          :font-family "Oswald"
          :font-weight "444"
          :fill        "#333"
          :text-anchor "end"}
   label])
