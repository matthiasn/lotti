(ns meins.electron.renderer.charts.data)

(defn remaining-times
  "Calculate remaining times by subtracting actual from allocated times. Only
   returns those where there's time left."
  [actual-times time-allocation]
  (let [remaining-mapper (fn [[k v]]
                           (let [allocation (or v 0)
                                 actual (get-in actual-times [k] 0)
                                 remaining (- allocation actual)]
                             [k remaining]))]
    (into {} (filter #(pos? (second %)) (map remaining-mapper time-allocation)))))

(defn past-7-days
  "Sums logged times for the last week, not including current day."
  [tk stats]
  (->> stats
       (map (fn [[k v]] [k (tk v)]))
       (sort-by first)
       (drop-last 1)
       (take-last 7)
       (map second)
       (apply merge-with #(int (+ %1 %2)))))

(defn stacked-reducer
  [acc [k v]]
  (let [total (get acc :total 0)]
    (-> acc
        (assoc-in [:total] (+ total v))
        (assoc-in [:items k :v] v)
        (assoc-in [:items k :x] total))))

(defn time-by-entity-stacked
  "build data structure for stacked horizontal chart"
  [time-by-entities]
  (let [sorted (sort-by #(str (first %)) time-by-entities)
        stacked-by-entity (reduce stacked-reducer {} sorted)]
    (reverse (sort-by #(str (first %)) (:items stacked-by-entity)))))
