(ns meo.electron.renderer.ui.charts.correlation
  (:require [reagent.core :as r]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info debug]]
            [meo.electron.renderer.helpers :as h]
            [matthiasn.systems-toolbox.switchboard.helpers :as sh]
            [meo.electron.renderer.ui.data-explorer :as dex]
            [re-frame.core :refer [subscribe]]))

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

(defn scatter-matrix [put-fn]
  (let [gql-res (subscribe [:gql-res])
        dashboard-data (reaction (get-in @gql-res [:dashboard :data]))
        questionnaire-data (reaction (get-in @gql-res [:dashboard-questionnaires :data]))
        day-stats (reaction (get-in @gql-res [:day-stats :data :day_stats]))
        panas-stats (reaction
                      (->> @questionnaire-data
                           :PANAS_pos
                           (map (fn [{:keys [timestamp score]}]
                                  (when score
                                    [(h/ymd timestamp) score])))
                           (filter identity)
                           (reduce (fn [acc [k v]]
                                     (update-in acc [k :panas-pos] conj v))
                                   {})))
        panas-stats2 (reaction
                      (->> @questionnaire-data
                           :PANAS_neg
                           (map (fn [{:keys [timestamp score]}]
                                  (when score
                                    [(h/ymd timestamp) score])))
                           (filter identity)
                           (reduce (fn [acc [k v]]
                                     (update-in acc [k :panas-neg] conj v))
                                   @panas-stats)))
        cfq11-stats (reaction
                      (->> @questionnaire-data
                           :CFQ11_total
                           (map (fn [{:keys [timestamp score]}]
                                  (when score
                                    [(h/ymd timestamp) score])))
                           (filter identity)
                           (reduce (fn [acc [k v]]
                                     (update-in acc [k :cfq11] conj v))
                                   @panas-stats2)))
        combined (reaction
                   (reduce (fn [acc {:keys [day entry_count word_count done_tasks_cnt]}]
                             (-> acc
                                 (assoc-in [day :word-count] word_count)
                                 (assoc-in [day :entry-count] entry_count)
                                 (assoc-in [day :completed-tasks] done_tasks_cnt)))
                           @cfq11-stats
                           @day-stats))
        combined2 (reaction
                    (->> @dashboard-data
                         :sleep
                         (reduce (fn [acc {:keys [date_string fields]}]
                                   (-> acc
                                       (assoc-in [date_string :sleep] (get-in fields [0 :value]))))
                                 @combined)))
        combined3 (reaction
                    (->> @dashboard-data
                         :coffee
                         (reduce (fn [acc {:keys [date_string fields]}]
                                   (-> acc
                                       (assoc-in [date_string :coffee] (get-in fields [0 :value]))))
                                 @combined2)))
        combined4 (reaction
                    (->> @dashboard-data
                         :steps
                         (reduce (fn [acc {:keys [date_string fields]}]
                                   (-> acc
                                       (assoc-in [date_string :steps] (get-in fields [0 :value]))))
                                 @combined3)))
        combined-vals (reaction (vals @combined4))
        ks [:panas-pos :panas-neg :sleep :cfq11 :steps :coffee :word-count
            :entry-count :completed-tasks]
        matrix (partition (count ks) (sh/cartesian-product ks ks))
        idx (fn [idx v] [idx v])]
    (fn scatter-matrix-render [put-fn]
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
