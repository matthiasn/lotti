(ns meins.jvm.graphql.common
  (:require [meins.jvm.graph.query :as gq]))

(def d (* 24 60 60 1000))

(defn entry-w-comments [state entry]
  (let [comments (mapv #(gq/get-entry-xf state %) (:comments entry))]
    (assoc-in entry [:comments] comments)))

(defn linked-for [state entry]
  (let [ts (:timestamp entry)
        g (:graph state)]
    (assoc-in entry [:linked] (->> (gq/get-linked-for-ts g ts)
                                   (map #(gq/entry-w-story state (gq/get-entry-xf state %)))
                                   (filter :timestamp)
                                   (vec)))))
