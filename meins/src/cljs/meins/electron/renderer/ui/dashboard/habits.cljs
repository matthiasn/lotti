(ns meins.electron.renderer.ui.dashboard.habits
  (:require [matthiasn.systems-toolbox.component :as st]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.dashboard.common :as dc]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug info]]))

(defn habits-chart
  [{:keys [habit]}]
  (let [dashboard-data (subscribe [:dashboard-data])
        habits (subscribe [:habits])
        habit-entry (reaction (get-in @habits [habit :habit_entry]))]
    (fn habits-chart-render [{:keys [y w h start end x-offset days]}]
      (let [label (eu/first-line @habit-entry)
            start-ymd (h/ymd start)
            end-ymd (h/ymd end)
            data (->> @dashboard-data
                      (filter #(<= start-ymd (first %)))
                      (filter #(> end-ymd (first %)))
                      (map second)
                      (map #(get-in % [:habits habit])))
            h (or h 25)
            btm-y (+ y h)
            span (- end start)
            mapper (fn [idx {:keys [success day]}]
                     (let [prior (< (+ start (* idx (/ span days))) habit)
                           current (= idx days)
                           common {:idx     idx
                                   :key     (str label idx)
                                   :opacity (if prior 0.3 (if current 0.5 1))
                                   :fill    (if success "green" "red")}]
                       (when (<= day (h/ymd (st/now)))
                         (if success
                           [:circle
                            (merge common
                                   {:cx (+ x-offset 8 (* idx (/ w (inc days))))
                                    :cy (- btm-y 12)
                                    :r  8})]
                           [:rect
                            (merge common
                                   {:x      (+ x-offset (* idx (/ w (inc days))))
                                    :y      (- btm-y 20)
                                    :width  16
                                    :height 16})]))))
            points (map-indexed mapper data)]
        [:g
         [dc/line y "#000" 2]
         [dc/line (+ y h) "#000" 2]
         [dc/row-label label y h]
         (for [p points] p)]))))
