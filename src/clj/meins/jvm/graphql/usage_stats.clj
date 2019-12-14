(ns meins.jvm.graphql.usage-stats
  (:require [buddy.core.codecs :refer [bytes->hex]]
            [buddy.core.hash :as hash]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.jvm.graph.query :as gq]
            [meins.jvm.graph.stats :as gs]
            [meins.jvm.usage :as usage]
            [taoensso.timbre :refer [debug error info warn]]))

(defn usage-stats-by-day
  [state _context args _value]
  (let [start (stc/now)
        {:keys [geohash_precision]} args
        current-state @state
        cfg (:cfg current-state)
        node-id (:node-id cfg)
        entries (map #(gq/get-entry current-state %) (:sorted-entries current-state))
        geohashes (->> entries
                       (map :geohash)
                       (filter identity)
                       (map #(subs % 0 geohash_precision))
                       set
                       vec)
        entries-total (count entries)
        hours-logged-total (Math/floor (gs/hours-logged current-state))
        sagas (count (gq/find-all-sagas2 current-state))
        stories (count (gq/find-all-stories2 current-state))
        habits (count (gq/find-all-habits current-state))
        hashtags (count (gq/find-all-hashtags current-state))
        tasks (gs/res-count current-state {:tags #{"#task"} :n Integer/MAX_VALUE})
        tasks-completed (gs/completed-count current-state)
        wordcount (gs/count-words current-state)
        id-hash (subs (bytes->hex (hash/sha1 node-id)) 0 10)
        res {:id_hash      id-hash
             :entries      entries-total
             :hours_logged hours-logged-total
             :geohashes    geohashes
             :hashtags     hashtags
             :tasks        tasks
             :tasks_done   tasks-completed
             :habits       habits
             :words        wordcount
             :stories      stories
             :os           (System/getProperty "os.name")
             :sagas        sagas}
        res (merge res {:dur (- (stc/now) start)})]
    (usage/upload-usage res)
    res))
