(ns meo.electron.renderer.ui.dashboard
  (:require [moment]
            [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.dashboard.common :as dc]
            [meo.electron.renderer.ui.dashboard.bp :as bp]
            [meo.electron.renderer.ui.dashboard.earlybird :as eb]
            [meo.electron.renderer.ui.dashboard.scores :as ds]
            [meo.electron.renderer.ui.dashboard.commits :as c]
            [meo.electron.renderer.ui.dashboard.habits :as h]
            [meo.electron.renderer.graphql :as gql]
            [taoensso.timbre :refer-macros [info debug]]
            [matthiasn.systems-toolbox.component :as st]
            [meo.electron.renderer.helpers :as rh]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.common.utils.parse :as up]))

(defn gql-query [charts-pos days put-fn]
  (let [tags (->> (:charts @charts-pos)
                  (filter #(contains? #{:barchart_row} (:type %)))
                  (mapv :tag))]
    (when-let [query-string (gql/graphql-query (inc days) tags)]
      (info "dashboard tags" query-string)
      (put-fn [:gql/query {:q        query-string
                           :res-hash nil
                           :id       :dashboard
                           :prio     15}])))
  (let [items (->> (:charts @charts-pos)
                   (filter #(= :questionnaire (:type %))))]
    (when-let [query-string (gql/dashboard-questionnaires days items)]
      (info "dashboard" query-string)
      (put-fn [:gql/query {:q        query-string
                           :res-hash nil
                           :id       :dashboard-questionnaires
                           :prio     15}]))))

(defn dashboard [days put-fn]
  (let [gql-res2 (subscribe [:gql-res2])
        local (r/atom {:idx   0
                       :play  false
                       :min-h 320})
        dashboards (reaction (-> @gql-res2 :dashboard_cfg :res))
        dashboard (reaction (-> @dashboards
                                vals
                                (nth (min (:idx @local) (dec (count @dashboards))))))
        charts-pos (reaction
                     (let [ts (:timestamp @dashboard)
                           new-entry @(:new-entry (eu/entry-reaction ts))
                           entry (or new-entry @dashboard)
                           items (:items (:dashboard_cfg entry))
                           acc {:last-y 50
                                :last-h 0}
                           f (fn [acc m]
                               (let [{:keys [last-y last-h]} acc
                                     cfg (assoc-in m [:y] (+ last-y last-h))]
                                 {:last-y (:y cfg)
                                  :last-h (:h cfg 25)
                                  :charts (conj (:charts acc) cfg)}))]
                       (reduce f acc items)))]
    (fn dashboard-render [days put-fn]
      (let [now (st/now)
            n (count @dashboards)
            next-item #(if (= % (dec n)) 0 (min (dec n) (inc %)))
            prev-item #(if (zero? %) (dec n) (max 0 (dec %)))
            cycle (fn [f _] (swap! local update-in [:idx] f))
            play (fn [_]
                   (let [f #(swap! local update-in [:idx] next-item)
                         t (js/setInterval f 60000)]
                     (swap! local assoc-in [:play] true)
                     (swap! local assoc-in [:timer] t)))
            pause (fn []
                    (js/clearInterval (:timer @local))
                    (swap! local assoc-in [:play] false))
            open-cfg #(put-fn [:search/add
                               {:tab-group :right
                                :query     (up/parse-search (:timestamp @dashboard))}])
            d (* 24 60 60 1000)
            within-day (mod now d)
            start (+ dc/tz-offset (- now within-day (* days d)))
            end (+ (- now within-day) d dc/tz-offset)
            span (- end start)
            common {:start    start
                    :end      end
                    :w        1800
                    :x-offset 200
                    :span     span
                    :days     days}
            end-y (+ (:last-y @charts-pos) (:last-h @charts-pos))]
        (gql-query charts-pos days put-fn)
        [:div.questionnaires
         [:div.controls
          [:input {:type      :number
                   :step      10
                   :on-change #(let [v (.. % -target -value)
                                     parsed (when (seq v) (js/parseFloat v))]
                                 (swap! local assoc-in [:min-h] parsed))
                   :value     (:min-h @local)}]
          [:i.fas.fa-cog {:on-click open-cfg}]
          [:i.fas.fa-step-forward {:on-click (partial cycle next-item)}]
          [:i.fas {:class    (if (:play @local) "fa-pause" "fa-play")
                   :on-click (if (:play @local) pause play)}]
          [:i.fas.fa-step-backward {:on-click (partial cycle prev-item)}]]
         [:svg {:viewBox (str "0 0 2100 " (+ (max end-y (:min-h @local)) 60))
                :style   {:background :white}
                :key     (str (:timestamp @dashboard) (:idx @local))}
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
                             :habit_success h/habits-chart
                             :questionnaire ds/scores-chart
                             ;:commits-chart c/commits-chart
                             ;:earlybird-chart eb/earlybird-chart
                             ;:bp-chart bp/bp-chart
                             :barchart_row dc/barchart-row
                             ;:points-by-day dc/points-by-day-chart
                             ;:points-lost-by-day dc/points-lost-by-day-chart
                             nil)]
              (when chart-fn
                ^{:key (str (:label chart-cfg) (:tag chart-cfg) (:k chart-cfg))}
                [rh/error-boundary [chart-fn (merge common chart-cfg) put-fn]])))
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
