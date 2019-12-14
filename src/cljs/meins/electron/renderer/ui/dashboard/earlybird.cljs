(ns meins.electron.renderer.ui.dashboard.earlybird
  (:require ["moment" :as moment]
            [meins.electron.renderer.ui.charts.common :as cc]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [info]]))

(defn line [y s w]
  [:line {:x1           195
          :x2           2000
          :y1           y
          :y2           y
          :stroke-width w
          :stroke       s}])

(defn row-label [label y h]
  [:text {:x           120
          :y           (+ y (+ 5 (/ h 2)))
          :font-size   12
          :fill        "#777"
          :text-anchor "end"}
   label])

(defn legend [text x y]
  [:text {:x           x
          :y           y
          :stroke      "none"
          :fill        "#AAA"
          :text-anchor :middle
          :style       {:font-size 12}}
   text])

(defn ts-bars [{:keys [day-stats item-name-k idx chart-h y-offset x-offset w x-step]} local]
  (let [day (moment (:day day-stats))
        mouse-enter-fn (cc/mouse-enter-fn local day-stats)
        mouse-leave-fn (cc/mouse-leave-fn local day-stats)
        y-scale (/ chart-h 90000)
        midnight (* 24 60 60 y-scale)
        midnight-s (* 1 60 60 y-scale)
        time-by-ts (:by_ts day-stats)
        time-by-h (map (fn [x]
                         (let [ts (:timestamp x)
                               h (/ (- ts day) 1000 60 60)]
                           [h x])) time-by-ts)]
    [:g {:on-mouse-enter mouse-enter-fn
         :on-mouse-leave mouse-leave-fn}
     (for [[hh {:keys [summed manual story]}] time-by-h]
       (let [item-name (if (= item-name-k :story_name)
                         (:story_name story)
                         (:saga_name (:saga story)))
             item-color (cc/item-color item-name "dark")
             h (* y-scale summed)
             y (* y-scale (+ hh 2) 60 60)
             y (if (pos? manual) (- y h) y)]
         ^{:key (str item-name hh)}
         [:g
          (let [h (min h (- midnight y))
                h (if (< y midnight-s)
                    (- h (- midnight-s y))
                    h)
                h (max h 0)
                y (max midnight-s y)
                y (+ y y-offset)]

            [:rect {:fill           item-color
                    :on-mouse-enter #(prn item-name hh summed)
                    :x              (+ (* x-step idx) x-offset)
                    :y              y
                    :width          w
                    :height         h}])
          (when (> (+ y h) midnight)
            (let [h (- (+ y h) midnight)
                  y midnight-s
                  y (+ y y-offset)]
              [:rect {:fill           item-color
                      :on-mouse-enter #(prn item-name hh summed)
                      :x              (+ (* x-step (inc idx)) x-offset)
                      :y              y
                      :width          w
                      :height         h}]))
          (when (< y midnight-s)
            (let [h (- midnight-s y)
                  y (- midnight h)
                  y (+ y y-offset)]
              [:rect {:fill           item-color
                      :on-mouse-enter #(prn item-name hh summed)
                      :x              (+ (* x-step (dec idx)) x-offset)
                      :y              y
                      :width          w
                      :height         h}]))]))]))

(defn earlybird-chart [_ _]
  (let [local (r/atom {})
        gql-res (subscribe [:gql-res])
        idx-fn (fn [idx v] [idx v])
        stats (reaction (:day_stats (:data (:day-stats @gql-res))))]
    (fn earlybird-chart-row [{:keys [days span h y]} put-fn]
      (let [indexed2 (map-indexed idx-fn @stats)
            l (/ h 5)]
        [:g
         [row-label "24h Rhythm" y h]
         [legend "00:00" 175 (+ y (* l 0.5))]
         [legend "06:00" 175 (+ y (* l 1.5))]
         [legend "12:00" 175 (+ y (* l 2.5))]
         [legend "18:00" 175 (+ y (* l 3.5))]
         [legend "24:00" 175 (+ y (* l 4.5))]
         (for [[n item] indexed2]
           (let [d (* 24 60 60 1000)
                 x-step (* 1800 (/ d span))]
             ^{:key (str :earlybird n)}
             [:g
              #_
              (for [hi (range 28)]
                (let [y2 (* h (/ hi 28))
                      stroke-w (if (zero? (mod (- hi 2) 6)) 1 0.5)
                      stroke-w (if (or (< hi 2) (> hi 26)) 0 stroke-w)]
                  ^{:key hi}
                  [:line {:x1           217
                          :x2           2000
                          :y1           (+ y y2)
                          :y2           (+ y y2)
                          :stroke-width stroke-w
                          :stroke       "#666"}]))
              [ts-bars {:day-stats   item
                        :item-name-k :saga_name
                        :idx         (inc n)
                        :x-step      x-step
                        :chart-h     h
                        :w           (/ 1500 days)
                        :x-offset    200
                        :y-offset    y} local put-fn]]))
         [line (+ y h) "#000" 2]]))))
