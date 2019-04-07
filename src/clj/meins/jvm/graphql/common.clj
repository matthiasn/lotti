(ns meins.jvm.graphql.common
  (:require [meins.jvm.graph.query :as gq]))

(def d (* 24 60 60 1000))

(defn entries-w-logged [state entries]
  (let [logged-t (fn [comment-ts]
                   (or
                     (when-let [c (gq/get-entry state comment-ts)]
                       (let [path [:custom_fields "#duration" :duration]]
                         (+ (or (:completed_time c) 0)
                            (* 60 (or (get-in c path) 0)))))
                     0))
        task-total-t (fn [t]
                       (let [logged (apply + (map logged-t (:comments t)))]
                         (if (:task t)
                           (assoc-in t [:task :completed_s] logged)
                           t)))]
    (map task-total-t entries)))

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
