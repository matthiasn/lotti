(ns meins.common.habits.util)

(defn get-criteria [entry day]
  (if-let [versions (-> entry :habit :versions)]
    (let [version (->> versions
                       (filter (fn [[_k v]]
                                 (> (compare day (:valid_from v)) -1)))
                       (sort-by first)
                       last
                       first)]
      (get-in versions [version :criteria]))
    (-> entry :habit :criteria)))
