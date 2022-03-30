(ns meins.jvm.graphql.tasks
  (:require [meins.jvm.graph.query :as gq]
            [meins.jvm.graphql.common :as gc]
            [taoensso.timbre :refer [debug error info warn]]))

(def d (* 24 60 60 1000))

(defn cfg-mapper [entry]
  (let [story (:story entry)
        story (merge story (:story_cfg story))]
    (assoc entry :story story)))

(defn started-tasks
  [state _context args _value]
  (let [q {:tags     #{"#task"}
           :not-tags #{"#done" "#backlog" "#closed"}
           :opts     #{":started"}
           :n        Integer/MAX_VALUE
           :pvt      (:pvt args)}
        current-state @state
        res (gq/get-filtered2 current-state q)
        tasks (->> res
                   (map #(gq/entry-w-story current-state %))
                   (map cfg-mapper)
                   (mapv (partial gc/entry-w-comments current-state)))]
    tasks))

(defn open-tasks
  [state _context args _value]
  (let [q {:tags     #{"#task"}
           :not-tags #{"#done" "#backlog" "#closed"}
           :n        Integer/MAX_VALUE
           :pvt      (:pvt args)}
        current-state @state
        res (gq/get-filtered2 current-state q)
        tasks (->> res
                   (map #(gq/entry-w-story current-state %))
                   (map cfg-mapper)
                   (mapv (partial gc/entry-w-comments current-state)))]
    tasks))
