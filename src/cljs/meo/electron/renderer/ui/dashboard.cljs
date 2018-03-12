(ns meo.electron.renderer.ui.dashboard
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.helpers :as h]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.dashboard.common :as dc]
            [meo.electron.renderer.ui.dashboard.bp :as bp]
            [meo.electron.renderer.ui.dashboard.scores :as ds]
            [reagent.core :as r]
            [matthiasn.systems-toolbox.component :as st]))

(defn dashboard [days put-fn]
  (let [custom-field-stats (subscribe [:custom-field-stats])
        chart-data (subscribe [:chart-data])
        last-update (subscribe [:last-update])
        active-dashboard (subscribe [:active-dashboard])
        questionnaires (subscribe [:questionnaires])
        local (r/atom {:n 150})
        charts-pos (reaction
                     (reduce
                       (fn [acc m]
                         (let [{:keys [last-y last-h]} acc
                               cfg (assoc-in m [:y] (+ last-y last-h))]
                           {:last-y (:y cfg)
                            :last-h (:h cfg)
                            :charts (conj (:charts acc) cfg)}))
                       {:last-y 50
                        :last-h 0}
                       (get-in @questionnaires [:dashboards @active-dashboard])))]
    (fn dashboard-render [days put-fn]
      (h/keep-updated :stats/custom-fields days local @last-update put-fn)
      (h/keep-updated :stats/wordcount days local @last-update put-fn)
      (let [now (st/now)
            d (* 24 60 60 1000)
            within-day (mod now d)
            start (+ dc/tz-offset (- now within-day (* days d)))
            end (+ (- now within-day) d dc/tz-offset)
            span (- end start)
            custom-field-stats @custom-field-stats
            common {:start      start :end end :w 1800 :x-offset 200
                    :span       span :days days :stats custom-field-stats
                    :chart-data @chart-data}
            end-y (+ (:last-y @charts-pos) (:last-h @charts-pos))]
        [:div.questionnaires
         [:svg {:viewBox (str "0 0 2100 " (+ end-y 20))
                :style   {:background :white}}
          [:filter#blur1
           [:feGaussianBlur {:stdDeviation 3}]]
          [:g
           (for [n (range (+ 2 days))]
             (let [offset (+ (* n d) dc/tz-offset)
                   scaled (* 1800 (/ offset span))
                   x (+ 200 scaled)]
               ^{:key n}
               [dc/tick x "#CCC" 1 30 end-y]))]
          (for [chart-cfg (:charts @charts-pos)]
            (let [chart-fn (case (:type chart-cfg)
                             :scores-chart ds/scores-chart
                             :bp-chart bp/bp-chart
                             :barchart-row dc/barchart-row
                             :points-by-day dc/points-by-day-chart
                             :points-lost-by-day dc/points-lost-by-day-chart)]
              ^{:key (str (:label chart-cfg) (:tag chart-cfg) (:k chart-cfg))}
              [chart-fn (merge common chart-cfg) put-fn]))
          (for [n (range (inc days))]
            (let [offset (+ (* (+ n 0.5) d) dc/tz-offset)
                  scaled (* 1800 (/ offset span))
                  x (+ 200 scaled)
                  ts (+ start offset)
                  weekday (dc/df ts dc/weekday)
                  weekend? (get #{"Sat" "Sun"} weekday)]
              ^{:key n}
              [:g {:writing-mode "tb-rl"}
               [:text {:x           x
                       :y           36
                       :font-size   9
                       :fill        (if weekend? :red :black)
                       :text-anchor "middle"}
                (dc/df ts dc/month-day)]]))]]))))
