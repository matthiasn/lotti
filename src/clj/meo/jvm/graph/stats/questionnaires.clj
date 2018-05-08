(ns meo.jvm.graph.stats.questionnaires
  "Get stats from graph."
  (:require [meo.jvm.graph.query :as gq]
            [meo.electron.renderer.ui.questionnaires :as q]))

(defn questionnaires-by-tag
  "Calculates individual questionnaire scores."
  [current-state tag score-k]
  (let [k (get-in current-state [:cfg :questionnaires :mapping tag])
        n Integer/MAX_VALUE
        res (gq/get-filtered current-state {:tags #{tag} :n n})
        entries-map (:entries-map res)
        cfg (-> current-state :cfg :questionnaires :items k)
        score-mapper (fn [[ts entry]]
                       (let [path [:questionnaires k]
                             scores (q/scores entry path cfg)
                             score (get scores score-k)]
                         {:starred   (:starred entry)
                          :timestamp ts
                          :agg       (name score-k)
                          :label     (:label score)
                          :score     (:score score)}))]
    (mapv score-mapper entries-map)))
