(ns meo.electron.renderer.ui.dashboard.commits
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.dashboard.common :as dc]
            [meo.electron.renderer.helpers :as h]
            [reagent.core :as r]
            [meo.electron.renderer.ui.charts.common :as cc]))

(def month-day "DD.MM.")
(def ymd "YYYY-MM-DD")
(def weekday "ddd")
(defn df [ts format] (.format (moment ts) format))

(defn line [y s w]
  [:line {:x1           195
          :x2           2000
          :y1           y
          :y2           y
          :stroke-width w
          :stroke       s}])

(defn rect [{:keys []}]
  (let [local (r/atom {})
        click (fn [_] (swap! local update-in [:show-label] not))]
    (fn [{:keys [v x w y h cls ymd]}]
      [:g
       [:rect {:on-click click
               :x        x
               :y        (- y h)
               :width    w
               :height   h
               :class    (cc/weekend-class cls {:date-string ymd})}]
       (when (:show-label @local)
         [:text {:x           (+ x 11)
                 :y           (- y 5)
                 :font-size   8
                 :fill        "#777"
                 :text-anchor "middle"}
          v])])))

(defn indexed-days [stats start days]
  (let [d (* 24 60 60 1000)
        rng (range (inc days))
        indexed (map-indexed (fn [n v]
                               (let [offset (* n d)
                                     ts (+ start offset)
                                     ymd (df ts ymd)
                                     v (get-in stats [ymd :git-commits] 0)
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
          :text-anchor "end"}
   label])

(defn commits-chart [_ _]
  (let [show-pvt (subscribe [:show-pvt])
        gql-res (subscribe [:gql-res])]
    (fn barchart-row [{:keys [days span start h y]} put-fn]
      (let [btm-y (+ y h)
            data (get-in @gql-res [:dashboard :git-commits])
            indexed (map-indexed (fn [i x] [i x]) data)
            mx (apply max (map #(:commits (second %)) indexed))
            scale (if (pos? mx) (/ (- h 3) mx) 1)]
        [:g
         (when @show-pvt
           [row-label "#git-commit" y h])
         (for [[n {:keys [date-string commits weekday]}] indexed]
           (let [d (* 24 60 60 1000)
                 offset (* n d)
                 span (if (zero? span) 1 span)
                 scaled (* 1800 (/ offset span))
                 x (+ 201 scaled)
                 v commits
                 h (* v scale)]
             ^{:key (str :git-commits n)}
             [rect {:v   v
                    :x   x
                    :w   (/ 1500 days)
                    :ymd date-string
                    :y   btm-y
                    :h   h
                    :cls "done"
                    :n   n}]))
         [line (+ y h) "#000" 2]]))))