(ns meo.jvm.graph.stats.awards
  "Get stats from graph."
  (:require [ubergraph.core :as uber]
            [meo.jvm.datetime :as dt]
            [meo.jvm.graph.query :as gq]
            [meo.common.utils.misc :as u]
            [matthiasn.systems-toolbox.log :as l]
            [clojure.tools.logging :as log]
            [ubergraph.core :as uc]
            [clojure.pprint :as pp]))

(defn award-points-by [k initial entries]
  (let [done-entries (filter #(and (-> % k :done) (-> % k :points)) entries)
        skipped-entries (filter #(and (-> % k :skipped) (-> % k :points)) entries)
        by-day-fn (fn [acc entry]
                    (let [entity (k entry)
                          completion (:completion-ts entity)
                          points (:points entity)]
                      (if (and (pos? points) (seq completion) (:done entity))
                        (let [completion-day (subs completion 0 10)
                              path [:by-day completion-day k]]
                          (update-in acc path #(+ (or % 0) points)))
                        acc)))
        skipped-by-day-fn
        (fn [acc entry]
          (let [entity (k entry)
                next-ts (:next-entry entity)
                skipped-at (dt/fmt-from-long next-ts)
                points (:points entity)]
            (if (and (pos? points) (seq skipped-at))
              (let [skipped-day (subs skipped-at 0 10)
                    path [:by-day-skipped skipped-day k]]
                (update-in acc path #(+ (or % 0) points)))
              acc)))
        by-day (reduce by-day-fn initial done-entries)
        by-day-skipped (reduce skipped-by-day-fn by-day skipped-entries)
        total (->> done-entries
                   (map k)
                   (filter :done)
                   (map :points)
                   (filter identity)
                   (apply +))
        total-skipped (->> skipped-entries
                           (map k)
                           (filter :skipped)
                           (map (fn [entry]
                                  (let [penalty (:penalty entry)
                                        points (:points entry)]
                                    (if (and penalty (pos-int? penalty))
                                      penalty
                                      points))))
                           (filter identity)
                           (apply +))]
    (-> by-day-skipped
        (update-in [:total] #(+ (or % 0) total))
        (update-in [:total-skipped] #(+ (or % 0) total-skipped)))))

(defn claimed-points [current-state]
  (let [res (gq/get-filtered
              current-state {:tags #{"#reward"} :n Integer/MAX_VALUE})
        entries (vals (:entries-map res))]
    (->> entries
         (map :reward)
         (filter :claimed)
         (map :points)
         (filter identity)
         (apply +))))

(defn award-points [current-state]
  (let [q {:tags #{"#habit"} :n Integer/MAX_VALUE}
        entries (->> (gq/get-filtered current-state q) :entries-map vals)
        by-habit (award-points-by :habit {:total 0} entries)
        q2 {:tags #{"#task"} :opts #{":done"} :n Integer/MAX_VALUE}
        by-task (vals (:entries-map (gq/get-filtered current-state q2)))
        by-habit-and-task (award-points-by :task by-habit by-task)
        claimed (claimed-points current-state)]
    (merge by-habit-and-task
           {:claimed claimed})))
