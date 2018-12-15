(ns meo.jvm.graphql.tasks
  (:require [meo.jvm.graph.query :as gq]
            [taoensso.timbre :refer [info error warn debug]]
            [meo.jvm.graphql.common :as gc]))

(def d (* 24 60 60 1000))


(defn started-tasks [state context args value]
  (let [q {:tags     #{"#task"}
           :not-tags #{"#done" "#backlog" "#closed"}
           :opts     #{":started"}
           :n        Integer/MAX_VALUE
           :pvt      (:pvt args)}
        current-state @state
        g (:graph current-state)
        res (gq/get-filtered2 current-state q)
        tasks (->> res
                   (gc/entries-w-logged g)
                   (mapv #(gq/entry-w-story g %))
                   (filter #(not (:on_hold (:task %))))
                   (mapv (partial gc/entry-w-comments g)))]
    tasks))

(defn open-tasks [state context args value]
  (let [q {:tags     #{"#task"}
           :not-tags #{"#done" "#backlog" "#closed"}
           :n        Integer/MAX_VALUE
           :pvt      (:pvt args)}
        current-state @state
        g (:graph current-state)
        res (gq/get-filtered2 current-state q)
        tasks (->> res
                   (gc/entries-w-logged g)
                   (mapv #(gq/entry-w-story g %))
                   (mapv (partial gc/entry-w-comments g)))]
    tasks))