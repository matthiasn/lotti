(ns meins.electron.renderer.ui.dashboard.time_barchart
  (:require [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.dashboard.common :as dc]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer [debug info]]))

(defn rect
  [{:keys [v x w y h ymd color label local]}]
  (let [display-text [:span ymd ": " [:strong v] " " label]
        enter #(swap! local assoc :display-text display-text)
        leave #(swap! local assoc :display-text "")]
    [:g
     [:rect {:on-mouse-enter enter
             :on-mouse-leave leave
             :x              x
             :y              (- y h)
             :width          w
             :height         h
             :fill           color}]]))

(defn barchart-row [_]
  (let [dashboard-data (subscribe [:dashboard-data])
        pvt            (subscribe [:show-pvt])
        sagas          (subscribe [:sagas])]
    (fn barchart-row [{:keys [days span mx mn tag saga h y color fail-color local
                              cls threshold success-cls start end]}]
      (let [btm-y      (+ y h)
            start-ymd  (h/ymd start)
            end-ymd    (h/ymd end)
            data       (->> @dashboard-data
                            (filter #(<= start-ymd (first %)))
                            (filter #(> end-ymd (first %)))
                            (map (fn [[d m]]
                                   {:date_string d
                                    :v           (get-in m [:by-saga saga] 0)})))
            indexed    (map-indexed (fn [i x]
                                      [i (merge x {:day-ts (h/ymd-to-ts (:date_string x))})])
                                    data)
            label      (get-in @sagas [saga :saga_name])
            field-type :time
            mx2 (apply max (map :v data))
            scale      (if (pos? mx2) (/ (- h 3) mx2) 1)
            line-inc   (cond
                         (> mx2 12000) 10800
                         (> mx2 8000) 7200
                         (> mx2 4000) 3600
                         (> mx2 2000) 1800
                         (> mx2 1500) 900
                         (> mx2 800) 450
                         (> mx2 400) 250
                         (> mx2 100) 50
                         (> mx2 40) 25
                         :else 10)
            lines      (filter #(zero? (mod % line-inc)) (range 1 mx))]
        [:g
         [dc/row-label label y h]
         (for [n lines]
           ^{:key (str saga n)}
           [dc/line (- btm-y (* n scale)) "#888" 1])
         (when @pvt
           (for [n lines]
             ^{:key (str saga n)}
             [:text {:x           624
                     :y           (- (+ btm-y 5) (* n scale))
                     :font-size   11
                     :fill        "black"
                     :text-anchor "start"}
              (h/s-to-hh-mm n)]))
         (for [[n {:keys [date_string day-ts] :as m}] indexed]
           (let [v         (:v m 0)
                 offset    (- day-ts start)
                 span      (if (zero? span) 1 span)
                 scaled    (* days 20 (/ offset span))
                 x         (+ 201 scaled)
                 h         (* v scale)
                 cls       (if (and threshold (> v threshold))
                             success-cls
                             cls)
                 color     (if (and (> v (* (or mn 0) 60))
                                    (< v (* (or mx 1440) 60)))
                             color
                             fail-color)
                 display-v (if (= :time field-type)
                             (h/s-to-hh-mm v)
                             v)]
             ^{:key (str saga n)}
             [rect {:v     display-v
                    :x     x
                    :w     (- (/ (* days 18) days) 1)
                    :ymd   date_string
                    :y     btm-y
                    :h     h
                    :label label
                    :local local
                    :tag   tag
                    :cls   cls
                    :color color
                    :n     n}]))
         [dc/line (+ y h) "#000" 2]]))))
