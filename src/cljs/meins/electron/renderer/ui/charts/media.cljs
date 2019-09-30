(ns meins.electron.renderer.ui.charts.media
  (:require [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.charts.common :as cc]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as rc]
            [reagent.ratom :refer-macros [reaction]]))

(defn stacked-bars-fn
  "Renders bars for data set."
  [indexed local put-fn]
  (fn [k-1 cls-1 k-2 cls-2 k-3 cls-3 y-start y-end]
    (let [chart-h (- y-end y-start)
          max-val (apply max (map (fn [[_idx v]]
                                    (+ (k-1 v) (k-2 v) (k-3 v))) indexed))
          y-scale (/ chart-h (or max-val 1))]
      [:g
       (for [[idx v] indexed]
         (let [h-1 (* y-scale (k-1 v))
               h-2 (* y-scale (k-2 v))
               h-3 (* y-scale (k-3 v))
               mouse-enter-fn (cc/mouse-enter-fn local v)
               mouse-leave-fn (cc/mouse-leave-fn local v)
               common {:x              (* 10 idx)
                       :on-click       (cc/open-day-fn v put-fn)
                       :width          9
                       :on-mouse-enter mouse-enter-fn
                       :on-mouse-leave mouse-leave-fn}
               bar-1 {:y      (- y-end h-1)
                      :height h-1
                      :class  (cc/weekend-class cls-1 v)}
               bar-2 {:y      (- y-end h-2 h-1)
                      :height h-2
                      :class  (cc/weekend-class cls-2 v)}
               bar-3 {:y      (- y-end h-3 h-2 h-1)
                      :height h-3
                      :class  (cc/weekend-class cls-3 v)}]
           (when (pos? max-val)
             ^{:key (str "bar" k-1 k-2 idx)}
             [:g
              [:rect (merge common bar-1)]
              [:rect (merge common bar-2)]
              [:rect (merge common bar-3)]])))])))

(defn media-chart
  "Draws chart for daily media creation (photos, videos, audio)."
  [chart-h put-fn]
  (let [local (rc/atom {})
        chart-data (subscribe [:chart-data])
        stats (reaction (:media-stats @chart-data))
        last-update (subscribe [:last-update])]
    (fn [chart-h put-fn]
      (let [indexed (map-indexed (fn [idx [k v]] [idx v]) @stats)
            stacked-bars (stacked-bars-fn indexed local put-fn)]
        (h/keep-updated :stats/media 60 local @last-update)
        [:div
         [:svg
          {:viewBox (str "0 0 600 " chart-h)}
          [cc/chart-title "photos / audio / video"]
          [cc/bg-bars indexed local chart-h :daily-summaries]
          [stacked-bars :photo-cnt "done" :audio-cnt "backlog"
           :video-cnt "tasks" 50 150]]
         (when (:mouse-over @local)
           [:div.mouse-over-info (cc/info-div-pos @local)
            [:div (:date_string (:mouse-over @local))]
            [:div "Photos: " (:photo-cnt (:mouse-over @local))]
            [:div "Audio notes: " (:audio-cnt (:mouse-over @local))]
            [:div "Videos: " (:video-cnt (:mouse-over @local))]])]))))
