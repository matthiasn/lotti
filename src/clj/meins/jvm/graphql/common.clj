(ns meins.jvm.graphql.common
  (:require [meins.jvm.graph.query :as gq]))

(def d (* 24 60 60 1000))

(defn entries-w-logged [g entries]
  (let [logged-t (fn [comment-ts]
                   (or
                     (when-let [c (gq/get-entry g comment-ts)]
                       (let [path [:custom_fields "#duration" :duration]]
                         (+ (or (:completed_time c) 0)
                            (* 60 (or (get-in c path) 0)))))
                     0))
        task-total-t (fn [t]
                       (let [logged (apply + (map logged-t (:comments t)))]
                         (assoc-in t [:task :completed_s] logged)))]
    (map task-total-t entries)))


(defn entry-w-comments [g entry]
  (let [comments (mapv #(gq/get-entry g %) (:comments entry))]
    (assoc-in entry [:comments] comments)))


(defn linked-for [g entry]
  (let [ts (:timestamp entry)]
    (assoc-in entry [:linked] (->> (gq/get-linked-for-ts g ts)
                                   (map #(gq/entry-w-story g (gq/get-entry g %)))
                                   (filter :timestamp)
                                   (vec)))))

