(ns meins.jvm.graphql.common
  (:require [meins.jvm.graph.query :as gq]))

(def d (* 24 60 60 1000))

(defn entry-w-comments [state entry]
  (let [comments (mapv #(gq/get-entry state %) (:comments entry))]
    (assoc-in entry [:comments] comments)))

(defn linked-for [state entry]
  (let [ts (:timestamp entry)
        g (:graph state)]
    (assoc-in entry [:linked] (->> (gq/get-linked-for-ts g ts)
                                   (map #(gq/entry-w-story state (gq/get-entry state %)))
                                   (filter :timestamp)
                                   (vec)))))

(defn distinct-by
  "Returns a lazy sequence of the elements of coll removing duplicates of (f item).
   From: https://gist.github.com/briansunter/24cf3a357aaf2c4993cd6d6fd4c47980"
  ([f coll]
   (let [step (fn step [xs seen]
                (lazy-seq
                  ((fn [[h :as xs] seen]
                     (when-let [s (seq xs)]
                       (if (contains? seen (f h))
                         (recur (rest s) seen)
                         (cons h (step (rest s) (conj seen (f h)))))))
                    xs seen)))]
     (step coll #{}))))
