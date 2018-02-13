(ns meo.jvm.graph.stats.questionnaires
  "Get stats from graph."
  (:require [meo.jvm.graph.query :as gq]
            [meo.electron.renderer.ui.questionnaires :as q]))

(defn by-tag
  "Calculates individual questionnaire scores."
  [current-state tag k]
  (let [n Integer/MAX_VALUE
        res (gq/get-filtered current-state {:tags #{tag} :n n})
        entries-map (:entries-map res)
        cfg (-> current-state :cfg :questionnaires :items k)
        score-mapper (fn [[ts entry]]
                       (let [path [:questionnaires k]
                             scores (->> (q/scores entry path cfg)
                                         (map (fn [[k v]] [k (:score v)]))
                                         (into {:starred (:starred entry)}))]
                         [ts scores]))
        scores (into {} (mapv score-mapper entries-map))]
    {k scores}))

(defn questionnaires
  "Calculates scores for all defined questionnaires."
  [current-state]
  (let [mapping (-> current-state :cfg :questionnaires :mapping)
        scores (map (fn [[tag k]] (by-tag current-state tag k)) mapping)]
    (apply merge scores)))
