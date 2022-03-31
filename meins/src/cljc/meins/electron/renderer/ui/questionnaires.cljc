(ns meins.electron.renderer.ui.questionnaires)

(defn scores
  [entry q-path form-cfg]
  (let [score-mapper (fn [[k cfg]]
                       (let [ks (get-in entry q-path)
                             form-vals (vals (select-keys ks (:items cfg)))
                             items (filter identity form-vals)
                             cnt (count items)
                             complete? (= (count items) (count (:items cfg)))
                             res (apply + items)
                             res (if (and (= :avg (:type cfg)) (pos? cnt))
                                   (/ res cnt)
                                   res)]
                         (when complete?
                           [k (assoc-in cfg [:score] res)])))
        scores (map score-mapper (:aggregations form-cfg))]
    (into {} scores)))
