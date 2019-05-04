(ns meins.jvm.graphql.usage-stats
  (:require [meins.jvm.graph.query :as gq]
            [taoensso.timbre :refer [info error warn debug]]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.jvm.datetime :as dt]
            [meins.jvm.graphql.common :as gc]
            [meins.jvm.graph.stats :as gs]))

(defn usage-stats-by-day [state _context args _value]
  (let [{:keys [date_string]} args
        g (:graph @state)
        entries-by-day (gq/get-nodes-for-day g {:date_string date_string})
        geohashes (->> entries-by-day
                       (map (partial gq/get-entry @state))
                       (map :geohash)
                       (filter identity)
                       (map #(subs % 0 3))
                       set
                       vec)
        entries-total (count (:entries-map @state))
        hours-logged-total (Math/floor (gs/hours-logged @state))
        hours-logged (Math/floor (gs/hours-logged2 @state entries-by-day))]
    {:date_string     date_string
     :entries_total   entries-total
     :entries_created (count entries-by-day)
     :hours_logged hours-logged
     :hours_logged_total    hours-logged-total
     :geohashes       geohashes}))
