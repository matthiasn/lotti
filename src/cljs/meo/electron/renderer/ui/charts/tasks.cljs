(ns meo.electron.renderer.ui.charts.tasks
  (:require [reagent.core :as rc]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.charts.common :as cc]
            [meo.electron.renderer.helpers :as h]))

(defn tasks-chart
  "Draws chart for opened and closed tasks, where the bars for the counts of
   newly opened tasks are drawn above a horizontal line and those for closed
   tasks below this line. The size of the the bars scales automatically
   depending on the maximum count found in the data.
   On mouse-over on any of the bars, the date and the values for the date are
   shown in an info div next to the bars."
  [chart-h put-fn]
  (let [local (rc/atom {})
        chart-data (subscribe [:chart-data])
        stats (reaction (:task-stats @chart-data))
        last-update (subscribe [:last-update])]
    (fn [chart-h put-fn]
      (let [task-stats (:task-stats @chart-data)
            indexed (map-indexed (fn [idx [_k v]] [idx v]) task-stats)
            max-cnt (apply max (map (fn [[_idx v]]
                                      (max (:tasks-cnt v) (:done-cnt v)))
                                    indexed))]
        (h/keep-updated :stats/tasks 60 local @last-update put-fn)
        [:div
         [:svg
          {:viewBox (str "0 0 600 " chart-h)}
          [:g
           [cc/chart-title "Tasks opened/closed"]
           [cc/bg-bars indexed local chart-h :tasks]
           (when (pos? max-cnt)
             (for [[idx v] indexed]
               (let [headline-reserved 50
                     chart-h-half (/ (- chart-h headline-reserved) 2)
                     y-scale (/ chart-h-half (or max-cnt 1))
                     h-tasks (* y-scale (:tasks-cnt v))
                     h-done (* y-scale (:done-cnt v))
                     h-closed (* (/ y-scale 2) (:closed-cnt v))
                     x (* 10 idx)
                     mouse-enter-fn (cc/mouse-enter-fn local v)
                     mouse-leave-fn (cc/mouse-leave-fn local v)]
                 ^{:key (str "tbar" (:date-string v) idx)}
                 [:g {:on-mouse-enter mouse-enter-fn
                      :on-mouse-leave mouse-leave-fn
                      :on-click       (cc/open-day-fn v put-fn)}
                  [:rect {:x      x
                          :y      (+ (- chart-h-half h-done) headline-reserved)
                          :width  9
                          :height h-done
                          :class  (cc/weekend-class "done" v)}]
                  [:rect {:x      x
                          :y      (+ chart-h-half headline-reserved)
                          :width  9
                          :height h-tasks
                          :class  (cc/weekend-class "tasks" v)}]
                  [:rect {:x      x
                          :y      headline-reserved
                          :width  9
                          :height h-closed
                          :class  (cc/weekend-class "closed" v)}]])))]]
         (when (:mouse-over @local)
           (let [closed-cnt (:closed-cnt (:mouse-over @local))]
             [:div.mouse-over-info (cc/info-div-pos @local)
              [:div (:date-string (:mouse-over @local))]
              [:div "Created: " (:tasks-cnt (:mouse-over @local))]
              [:div "Done: " (:done-cnt (:mouse-over @local))]
              (when (pos? closed-cnt) [:div "Closed: " closed-cnt])]))]))))
