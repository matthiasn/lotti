(ns meins.jvm.graphql.usage-stats
  (:require [meins.jvm.graph.query :as gq]
            [taoensso.timbre :refer [info error warn debug]]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.jvm.datetime :as dt]
            [meins.jvm.graphql.common :as gc]
            [meins.jvm.graph.stats :as gs]))

(defn usage-stats-by-day [state _context args _value]
  (prn args)
  (let [{:keys [day_string]} args
        g (:graph @state)
        geohashes (->> (gq/get-nodes-for-day g {:date_string day_string})
                       (map (partial gq/get-entry @state))
                       (map :geohash)
                       (filter identity)
                       (map #(subs % 0 3))
                       set
                       vec)
        entry-count (count (:entries-map @state))
        hours-logged (gs/hours-logged @state)]
    {:date_string     day_string
     :entries_total   entry-count
     :entries_created 0
     :hours_logged    hours-logged
     :geohashes       geohashes}))
