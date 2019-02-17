(ns meins.jvm.graphql.tasks
  (:require [meins.jvm.graph.query :as gq]
            [taoensso.timbre :refer [info error warn debug]]
            [meins.jvm.graphql.common :as gc]))

(def d (* 24 60 60 1000))

(defn cfg-mapper [entry]
  (let [story (:story entry)
        story (merge story (:story_cfg story))]
    (assoc entry :story story)))

(defn started-tasks [state context args value]
  (let [q {:tags     #{"#task"}
           :not-tags #{"#done" "#backlog" "#closed"}
           :opts     #{":started"}
           :n        Integer/MAX_VALUE
           :pvt      (:pvt args)}
        current-state @state
        res (gq/get-filtered2 current-state q)
        tasks (->> res
                   (gc/entries-w-logged current-state)
                   (map #(gq/entry-w-story current-state %))
                   (map cfg-mapper)
                   (filter #(not (:on_hold (:task %))))
                   (mapv (partial gc/entry-w-comments current-state)))]
    tasks))

(defn open-tasks [state context args value]
  (let [q {:tags     #{"#task"}
           :not-tags #{"#done" "#backlog" "#closed"}
           :n        Integer/MAX_VALUE
           :pvt      (:pvt args)}
        current-state @state
        res (gq/get-filtered2 current-state q)
        tasks (->> res
                   (gc/entries-w-logged current-state)
                   (map #(gq/entry-w-story current-state %))
                   (map cfg-mapper)
                   (mapv (partial gc/entry-w-comments current-state)))]
    tasks))