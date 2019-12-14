(ns meins.electron.renderer.ui.dashboard.core
  (:require [matthiasn.systems-toolbox.component :as st]
            [meins.electron.renderer.graphql :as gql]
            [meins.electron.renderer.helpers :as rh]
            [meins.electron.renderer.ui.dashboard.bp :as bp]
            [meins.electron.renderer.ui.dashboard.cf-linechart :as cfl]
            [meins.electron.renderer.ui.dashboard.cf_barchart :as db]
            [meins.electron.renderer.ui.dashboard.commits :as c]
            [meins.electron.renderer.ui.dashboard.common :as dc]
            [meins.electron.renderer.ui.dashboard.habits :as h]
            [meins.electron.renderer.ui.dashboard.scores :as ds]
            [meins.electron.renderer.ui.dashboard.time_barchart :as dt]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug error info]]))

(def d (* 24 60 60 1000))

(defn gql-query [charts-pos days offset local dashboard-data pvt]
  (when-not (and (= (:days @local) days)
                 (= (:charts-pos @local) charts-pos)
                 (= (:offset-last @local) offset))
    (swap! local assoc :days days)
    (swap! local assoc :offset-last offset)
    (swap! local assoc :charts-pos charts-pos)
    (let [tags (->> (:charts charts-pos)
                    (filter #(contains? #{:barchart_row
                                          :linechart_row} (:type %)))
                    (mapv :tag)
                    (concat ["#BP" "#sleep"]))
          day-strings (mapv rh/n-days-ago-fmt (reverse (range offset (+ (* -1 offset) days days))))]
      (emit [:gql/query {:q        (gql/graphql-query-by-days day-strings tags :custom_fields_by_days)
                         :res-hash nil
                         :id       :custom_fields_by_days
                         :prio     15}]))
    (let [items (->> (:charts charts-pos)
                     (filter #(= :questionnaire (:type %))))
          day-strings (mapv rh/n-days-ago-fmt (range 0 (+ (* -1 offset) days days)))]
      (doseq [item items]
        (let [tag (:tag item)
              day-strings (filter #(not (get-in dashboard-data [% tag])) day-strings)]
          (emit [:gql/query {:q        (gql/dashboard-questionnaires-by-days day-strings item)
                             :res-hash nil
                             :id       :questionnaires-by-days
                             :prio     15}]))))
    (let [day-strings (->> (range 0 (+ (* -1 offset) days days))
                           (mapv rh/n-days-ago-fmt)
                           (filter #(empty? (get-in dashboard-data [% :habits]))))]
      (emit [:gql/query {:q        (gql/habits-query-by-days day-strings pvt)
                         :res-hash nil
                         :id       :habits-by-days
                         :prio     15}]))))

(defn charts-positions [dashboard habits]
  (let [ts (:timestamp dashboard)
        new-entry @(:new-entry (eu/entry-reaction ts))
        entry (or new-entry dashboard)
        items (:items (:dashboard_cfg entry))
        item-filter #(if (= :habit_success (:type %))
                       (get-in @habits [(:habit %) :habit_entry :habit :active])
                       true)
        items (filter item-filter items)
        acc {:last-y 50
             :last-h 0}
        f (fn [acc m]
            (let [{:keys [last-y last-h]} acc
                  cfg (assoc-in m [:y] (+ last-y last-h))]
              {:last-y (:y cfg)
               :last-h (:h cfg 25)
               :charts (conj (:charts acc) cfg)}))]
    (reduce f acc items)))

(defn dashboard [{:keys [days]}]
  (let [gql-res2 (subscribe [:gql-res2])
        dashboard-data (subscribe [:dashboard-data])
        habits (subscribe [:habits])
        local (r/atom {:idx          0
                       :play         false
                       :display-text ""
                       :offset       0})
        pvt (subscribe [:show-pvt])
        pvt-filter (fn [x] (if @pvt true (not (get-in x [1 :dashboard_cfg :pvt]))))
        active-filter (fn [x] (get-in x [1 :dashboard_cfg :active]))
        not-empty-filter (fn [x] (seq (get-in x [1 :dashboard_cfg :items])))
        dashboards (reaction (->> @gql-res2
                                  :dashboard_cfg
                                  :res
                                  (filter pvt-filter)
                                  (filter active-filter)
                                  (filter not-empty-filter)
                                  (into {})))
        dashboard (reaction
                    (let [n (count @dashboards)
                          dashboard-idx (min (:idx @local) (dec n))]
                      (when (pos? n)
                        (try
                          (nth (vals @dashboards) dashboard-idx)
                          (catch js/Object e
                            (error dashboard-idx e)
                            (first @dashboards))))))
        charts-pos (reaction (charts-positions @dashboard habits))
        run-query #(let [dashboard-ts (:timestamp @dashboard)]
                     (when (not= dashboard-ts (:dashboard-ts @local))
                       (swap! local assoc :dashboard-ts dashboard-ts)
                       (gql-query @charts-pos days (:offset @local) local @dashboard-data @pvt)))
        on-wheel (fn [ev]
                   (let [delta-x (int (/ (.-deltaX ev) 4))]
                     (swap! local update :offset + delta-x)
                     (when-not (:timeout @local)
                       (swap! local assoc :timeout
                              (js/setTimeout
                                #(do (gql-query @charts-pos days (:offset @local) local @dashboard-data @pvt)
                                     (swap! local assoc :timeout nil))
                                100)))))]
    (fn dashboard-render [{:keys [days controls dashboard-ts]}]
      (run-query)
      (let [last-ts (+ (st/now) (* (:offset @local) d))
            n (count @dashboards)
            dashboard (or (get @dashboards dashboard-ts)
                          @dashboard)
            charts-pos (charts-positions dashboard habits)
            next-item #(if (= % (dec n)) 0 (min (dec n) (inc %)))
            prev-item #(if (zero? %) (dec n) (max 0 (dec %)))
            cycle (fn [f _]
                    (run-query)
                    (swap! local update-in [:idx] f))
            play (fn [_]
                   (let [f #(swap! local update-in [:idx] next-item)
                         t (js/setInterval f (* 5 60 1000))]
                     (swap! local assoc-in [:play] true)
                     (swap! local assoc-in [:timer] t)))
            pause (fn []
                    (js/clearInterval (:timer @local))
                    (swap! local assoc-in [:play] false))
            within-day (mod last-ts d)

            start (+ dc/tz-offset (- last-ts within-day (* days d)))
            end (+ (- last-ts within-day) d dc/tz-offset)

            w (* days 20)

            span (- end start)
            common {:start    start
                    :end      end
                    :h        25
                    :w        (* days 20)
                    :x-offset 200
                    :local    local
                    :span     span
                    :days     days}
            end-y (+ (:last-y charts-pos) (:last-h charts-pos))
            text (eu/first-line dashboard)
            text (or (when (seq text)
                       text)
                     "YOUR DASHBOARD DESCRIPTION HERE")]
        (when dashboard
          [:div.dashboard {:on-wheel on-wheel}
           [:h2 text]
           [:svg {:viewBox (str "0 0 " (+ w 260) " " (+ end-y 6))
                  :style   {:background :white}
                  :key     (str (:timestamp dashboard) (:idx @local))}
            [:filter#blur1
             [:feGaussianBlur {:stdDeviation 3}]]
            [:g
             (for [n (range (+ 2 days))]
               (let [offset (+ (* n d) dc/tz-offset)
                     scaled (* w (/ offset span))
                     x (+ 200 scaled)]
                 ^{:key n}
                 [dc/tick x "#CCC" 1 30 end-y]))]
            (for [chart-cfg (:charts charts-pos)]
              (let [chart-fn (case (:type chart-cfg)
                               :habit_success h/habits-chart
                               :questionnaire ds/scores-chart
                               :barchart_row db/barchart-row
                               :time_barchart dt/barchart-row
                               :linechart_row cfl/linechart-row
                               :bp_chart bp/bp-chart
                               :commits-chart c/commits-chart
                               ;:earlybird-chart eb/earlybird-chart
                               ;:points-by-day dc/points-by-day-chart
                               ;:points-lost-by-day dc/points-lost-by-day-chart
                               nil)]
                (when chart-fn
                  ^{:key (str chart-cfg)}
                  [rh/error-boundary [chart-fn (merge common chart-cfg)]])))
            (for [n (range (inc days))]
              (let [x-offset (+ (* (+ n 0.5) d) dc/tz-offset)
                    scaled (* w (/ x-offset span))
                    x (+ 201 scaled)
                    ts (+ start x-offset)
                    weekday (dc/df ts dc/weekday)
                    weekend? (get #{"Sat" "Sun"} weekday)]
                ^{:key n}
                [:g {:writing-mode "tb-rl"}
                 [:text {:x           x
                         :y           36
                         :font-size   12
                         :font-weight (if weekend? :normal :light)
                         :fill        (if weekend? :red :black)
                         :text-anchor "middle"}
                  (dc/df ts dc/month-day)]]))]
           [:div.controls
            [:span.display-text (:display-text @local)]
            [:div.ctrl
             (when (and controls (< 1 (count @dashboards)))
               [:div.btns
                ;[:i.fas.fa-cog {:on-click open-cfg}]
                [:i.fas.fa-step-backward {:on-click (partial cycle prev-item)}]
                [:i.fas {:class    (if (:play @local) "fa-pause" "fa-play")
                         :on-click (if (:play @local) pause play)}]
                [:i.fas.fa-step-forward {:on-click (partial cycle next-item)}]])
             [:div.offset {:on-click #(do (gql-query charts-pos days 0 local @dashboard-data @pvt)
                                   (swap! local assoc :offset 0))}
              (when-not (zero? (:offset @local))
                (:offset @local))]]]])))))

