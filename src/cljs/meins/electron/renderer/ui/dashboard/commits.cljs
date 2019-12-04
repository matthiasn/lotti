(ns meins.electron.renderer.ui.dashboard.commits
  (:require [meins.electron.renderer.ui.charts.common :as cc]
            [meins.electron.renderer.ui.dashboard.common :as dc]
            [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug error info]]
            [tinycolor2 :as tinycolor]))

(defn rect [{:keys []}]
  (let [local (r/atom {})
        click (fn [_] (swap! local update-in [:show-label] not))]
    (fn [{:keys [v mx x w y h color cls ymd]}]
      (let [tc (new tinycolor color)
            lighten-by (/ 1 (/ v mx))
            lightened (.lighten tc lighten-by)]
        [:g
         [:rect {:on-click click
                 :x        x
                 :y        (- y h)
                 :width    w
                 :height   h
                 :fill     (.toString lightened)
                 :class    (cc/weekend-class cls {:date_string ymd})}]
         (when (:show-label @local)
           [:text {:x           (+ x 11)
                   :y           (- y 5)
                   :font-size   8
                   :fill        "#777"
                   :text-anchor "middle"}
            v])]))))

(defn commits-chart [_]
  (let [gql-res (subscribe [:gql-res])]
    (fn barchart-row [{:keys [days span start h y color]}]
      (let [btm-y (+ y h)
            data (get-in @gql-res [:dashboard :data :git_stats])
            indexed (map-indexed (fn [i x] [i x]) data)
            mx (apply max (map #(:commits (second %)) indexed))
            scale (if (pos? mx) (/ (- h 3) mx) 1)]
        [:g
         [dc/row-label "#git-commit" y h]
         (for [[n {:keys [date-string commits weekday]}] indexed]
           (let [d (* 24 60 60 1000)
                 offset (* n d)
                 span (if (zero? span) 1 span)
                 scaled (* 1800 (/ offset span))
                 x (+ 201 scaled)
                 v commits]
             ^{:key (str :git-commits n)}
             [rect {:v     v
                     :mx    mx
                     :x     x
                     :w     (/ 1500 days)
                     :ymd   date-string
                     :y     btm-y
                     :color color
                     :h     (- h 5)
                     :cls   "done"
                     :n     n}]))
         [dc/line (+ y h) "#000" 2]]))))
