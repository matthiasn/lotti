(ns meo.jvm.graph.stats.git
  "Get stats about git commits from graph."
  (:require [taoensso.timbre :refer [info error warn debug]]
            [meo.jvm.graph.query :as gq]
            [ubergraph.core :as uber]))

(defn git-mapper
  "Creates mapper function for git stats. Takes current state. Returns
   function that takes date string, such as '2016-10-10', and returns map with
   the number of git commits, plus the date string."
  [current-state]
  (fn [d]
    (let [g (:graph current-state)
          date-string (:date-string d)
          day-nodes (gq/get-nodes-for-day g {:date-string date-string})
          day-nodes-attrs (map #(uber/attrs g %) day-nodes)
          nodes (filter :git-commit day-nodes-attrs)
          commits (count nodes)
          day-stats {:date-string date-string
                     :git-commits commits}]
      (info day-stats)
      [date-string day-stats])))
