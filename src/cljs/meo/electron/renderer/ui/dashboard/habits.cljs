(ns meo.electron.renderer.ui.dashboard.habits
  (:require [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info debug]]
            [reagent.ratom :refer-macros [reaction]]
            [camel-snake-kebab.core :refer [->kebab-case]]
            [meo.electron.renderer.ui.dashboard.common :as dc]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [clojure.string :as s]
            [moment]))

(defn habits-chart
  [{:keys [habit]} _put-fn]
  (let [show-pvt (subscribe [:show-pvt])
        habits (subscribe [:habits])
        habit-entry (reaction (get-in @habits [habit :habit_entry]))
        completions (reaction (->> (get-in @habits [habit :completed]) reverse))]
    (fn habits-chart-render [{:keys [y w h start end x-offset days]} put-fn]
      (let [label (eu/first-line @habit-entry)
            h (or h 25)
            btm-y (+ y h)
            span (- end start)
            mapper (fn [idx itm]
                     (let [prior (< (+ start (* idx (/ span days))) habit)
                           current (= idx days)]
                       {:cx      (+ x-offset 8 (* idx (/ w (inc days))))
                        :cy      (- btm-y 12)
                        :r       8
                        :idx     idx
                        :opacity (if prior 0.3 (if current 0.5 1))
                        :fill    (if (:success itm) "green" "red")}))
            points (map-indexed mapper @completions)]
        [:g
         [dc/line y "#000" 2]
         [dc/line (+ y h) "#000" 2]
         ;[:rect {:fill :white :x 0 :y y :height (+ h 5) :width 190}]
         (when @show-pvt
           [dc/row-label label y h])
         (for [p points]
           ^{:key (str label (:idx p))}
           [:circle p])]))))
