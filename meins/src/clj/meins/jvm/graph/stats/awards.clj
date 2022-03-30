(ns meins.jvm.graph.stats.awards
  "Get stats from graph."
  (:require [meins.jvm.graph.query :as gq]))

(defn award-points-by [k entries]
  (let [done-entries (filter #(and (-> % k :done) (-> % k :points)) entries)
        by-day-fn (fn [acc entry]
                    (let [entity (k entry)
                          completion (:completion_ts entity)
                          points (:points entity)]
                      (if (and (pos? points)
                               (seq completion)
                               (:done entity))
                        (let [completion-day (subs completion 0 10)
                              path [completion-day]]
                          (update-in acc path #(+ (or % 0) points)))
                        acc)))
        by-day (reduce by-day-fn {} done-entries)
        total (->> done-entries
                   (map k)
                   (filter :done)
                   (map :points)
                   (filter identity)
                   (apply +))]
    {:by_day (mapv (fn [[k v]] {:date_string k :task v}) by-day)
     :total  total}))

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
  (let [q {:tags #{"#task"} :opts #{":done"} :n Integer/MAX_VALUE}
        by-task (vals (:entries-map (gq/get-filtered current-state q)))
        by-habit-and-task (award-points-by :task by-task)
        claimed (claimed-points current-state)]
    (merge by-habit-and-task
           {:claimed claimed})))
