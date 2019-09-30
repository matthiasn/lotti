(ns meins.jvm.graph.stats.questionnaires
  "Get stats from graph."
  (:require [meins.electron.renderer.ui.questionnaires :as q]
            [meins.jvm.graph.query :as gq]))

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

(defn questionnaires-by-tag-day
  "Calculates individual questionnaire scores."
  [current-state tag day score-k]
  (let [k (get-in current-state [:cfg :questionnaires :mapping tag])
        n Integer/MAX_VALUE
        res (gq/get-filtered current-state {:date_string day :tags #{tag} :n n})
        entries-map (:entries-map res)
        cfg (-> current-state :cfg :questionnaires :items k)
        score-mapper (fn [[_ts entry]]
                       (let [path [:questionnaires k]
                             scores (q/scores entry path cfg)
                             score (get scores score-k)]
                         (merge entry {:agg         (name score-k)
                                       :label       (:label score)
                                       :score       (:score score)
                                       :tag         tag
                                       :date_string day})))]
    (mapv score-mapper entries-map)))
