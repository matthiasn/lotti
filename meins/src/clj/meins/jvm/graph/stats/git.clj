(ns meins.jvm.graph.stats.git
  "Get stats about git commits from graph."
  (:require [meins.jvm.graph.query :as gq]
            [taoensso.timbre :refer [debug error info warn]]))

(defn git-mapper
  "Creates mapper function for git stats. Takes current state. Returns
   function that takes date string, such as '2016-10-10', and returns map with
   the number of git commits, plus the date string."
  [current-state]
  (fn [date-string]
    (let [g (:graph current-state)
          day-nodes (gq/get-nodes-for-day g {:date_string date-string})
          day-nodes-attrs (map #(gq/get-entry current-state %) day-nodes)
          nodes (filter :git_commit day-nodes-attrs)
          day-stats {:date_string date-string
                     :commits     (count nodes)}]
      (debug day-stats)
      day-stats)))
