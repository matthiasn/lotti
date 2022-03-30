(ns meins.electron.renderer.ui.charts.correlation
  (:require [matthiasn.systems-toolbox.switchboard.helpers :as sh]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug info]]))

(defn scatter-plot [combined xk yk x-off y-off]
  (let [avg (fn [v] (if (seq? v)
                      (if (pos? (count v))
                        (/ (apply + v) (count v))
                        0)
                      v))
        max-x (apply max (map #(avg (xk %)) @combined))
        x-scale (if (pos? max-x) (/ 100 max-x) 1)
        max-y (apply max (map #(avg (yk %)) @combined))
        y-scale (if (pos? max-y) (/ 100 max-y) 1)
        points (map (fn [m]
                      {:x (* (avg (xk m)) x-scale)
                       :y (* (avg (yk m)) y-scale)})
                    @combined)]
    [:g
     (for [[i p] (map-indexed (fn [idx v] [idx v]) points)]
       ^{:key (str i)}
       [:circle {:cx    (+ x-off (:x p))
                 :cy    (- (+ y-off 100) (:y p))
                 :r     1.6
                 :style {:stroke  :green
                         :fill    :green
                         :opacity 0.6}}])
     [:line
      {:x1           x-off
       :y1           y-off
       :x2           x-off
       :y2           (+ y-off 100)
       :stroke       :black
       :stroke-width 1}]
     [:line
      {:x1           x-off
       :y1           (+ y-off 100)
       :x2           (+ x-off 100)
       :y2           (+ y-off 100)
       :stroke       :black
       :stroke-width 1}]
     [:text {:x           (+ x-off 10)
             :y           (+ y-off 110)
             :font-size   9
             :font-weight :bold
             :fill        "#333"}
      (name xk)]
     [:text {:x           (- x-off 4)
             :y           (+ y-off 90)
             :transform   (str "rotate(270," (- x-off 4) "," (+ y-off 90) ")")
             :font-size   9
             :font-weight :bold
             :fill        "#333"}
      (name yk)]]))

(defn data-xform [combined dashboard-data tag out-key]
  (reduce (fn [acc [date_string {:keys [custom-fields]}]]
            (let [v (get-in custom-fields [tag :fields 0 :value])]
              (assoc-in acc [date_string out-key] v)))
          combined
          dashboard-data))

(defn q-xform [combined dashboard-data tag score out-key]
  (reduce (fn [acc [date_string {:keys [questionnaires]}]]
            (let [v (:score (first (get-in questionnaires [tag (name score)])))]
              (update-in acc [date_string out-key] conj v)))
          combined
          dashboard-data))

(defn ds-xform [stats]
  (reduce (fn [acc {:keys [day entry_count word_count done_tasks_cnt]}]
            (-> acc
                (assoc-in [day :word-count] word_count)
                (assoc-in [day :entry-count] entry_count)
                (assoc-in [day :completed-tasks] done_tasks_cnt)))
          {}
          stats))

(defn scatter-matrix []
  (let [gql-res (subscribe [:gql-res])
        dashboard-data (subscribe [:dashboard-data])
        day-stats (reaction (get-in @gql-res [:day-stats :data :day_stats]))
        combined (reaction
                    (-> (ds-xform @day-stats)
                        (q-xform @dashboard-data "#PANAS" :pos :panas-pos)
                        (q-xform @dashboard-data "#PANAS" :neg :panas-neg)
                        (q-xform @dashboard-data "#CFQ11" :total :cfq11)
                        (data-xform @dashboard-data "#sleep" :sleep)
                        (data-xform @dashboard-data "#coffee" :coffee)
                        (data-xform @dashboard-data "#steps" :steps)))
        combined-vals (reaction (vals @combined))
        ks [:panas-pos :panas-neg :sleep :cfq11 :steps :coffee :word-count
            :entry-count :completed-tasks]
        matrix (partition (count ks) (sh/cartesian-product ks ks))
        idx (fn [idx v] [idx v])]
    (fn scatter-matrix-render []
      [:div.flex-container
       [:div.stats
        [:svg
         {:viewBox (str "0 0 1200 1200")}
         (for [[ri row] (map-indexed idx matrix)]
           (for [[ci itm] (map-indexed idx row)]
             (let [xk (first itm)
                   yk (second itm)
                   x-off (+ 20 (* ci 120))
                   y-off (+ 20 (* ri 120))]
               [scatter-plot combined-vals xk yk x-off y-off])))]]])))
