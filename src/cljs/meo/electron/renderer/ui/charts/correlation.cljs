(ns meo.electron.renderer.ui.charts.correlation
  (:require [reagent.core :as r]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.helpers :as h]
            [matthiasn.systems-toolbox.switchboard.helpers :as sh]
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
  (let [local (r/atom {})
        stats (subscribe [:stats])
        chart-data (subscribe [:chart-data])
        wordcount-stats (reaction (:wordcount-stats @chart-data))
        panas-stats (reaction
                      (->> @stats
                           :questionnaires
                           :panas
                           (map (fn [[k v]]
                                  (when (seq v)
                                    [(h/ymd k) v])))
                           (filter identity)
                           (reduce (fn [acc [k v]]
                                     (-> acc
                                         (update-in [k :panas-pos] conj (:pos v))
                                         (update-in [k :panas-neg] conj (:neg v))))
                                   {})))
        cfq11-stats (reaction
                      (->> @stats
                           :questionnaires
                           :cfq11
                           (map (fn [[k v]]
                                  (when v
                                    [(h/ymd k) v])))
                           (filter identity)
                           (reduce (fn [acc [k v]]
                                     (update-in acc [k :cfq11] conj (:total v)))
                                   @panas-stats)))
        custom-field-stats (subscribe [:custom-field-stats])
        combined (reaction
                   (->> @wordcount-stats
                        (reduce (fn [acc [k v]]
                                  (-> acc
                                      (assoc-in [k :word-count] (:word-count v))
                                      (assoc-in [k :entry-count] (:entry-count v))))
                                @cfq11-stats)))
        combined2 (reaction
                    (->> @custom-field-stats
                         (reduce (fn [acc [k v]]
                                   (-> acc
                                       (assoc-in [k :sleep] (get-in v ["#sleep" :duration]))
                                       (assoc-in [k :beer] (get-in v ["#beer" :vol]))
                                       (assoc-in [k :coffee] (get-in v ["#coffee" :cnt]))
                                       (assoc-in [k :steps] (or (get-in v ["#steps" :cnt]) 0))))
                                 @combined)))
        combined-vals (reaction (vals @combined2))
        last-update (subscribe [:last-update])
        ks [:panas-pos :panas-neg :sleep :cfq11 :steps :coffee :beer :word-count
            :entry-count]
        matrix (partition (count ks) (sh/cartesian-product ks ks))
        idx (fn [idx v] [idx v])]
    (fn scatter-matrix-render [put-fn]
      (let [n 120]
        (h/keep-updated :stats/custom-fields n local @last-update put-fn)
        (h/keep-updated :stats/wordcount n local @last-update put-fn)
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
                 [scatter-plot combined-vals xk yk x-off y-off])))]]]))))
