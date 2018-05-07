(ns meo.jvm.graph.stats
  "Get stats from graph."
  (:require [ubergraph.core :as uber]
            [meo.jvm.graph.query :as gq]
            [meo.jvm.graph.stats.awards :as aw]
            [meo.jvm.graph.stats.questionnaires :as q]
            [meo.jvm.graph.stats.custom-fields :as cf]
            [meo.jvm.graph.stats.git :as g]
            [meo.common.utils.misc :as u]
            [taoensso.timbre :refer [info error warn]]
            [clojure.set :as set]
            [clj-pid.core :as pid]
            [matthiasn.systems-toolbox.component :as st]))

(defn media-mapper
  "Create mapper function for media stats"
  [current-state]
  (fn [d]
    (let [g (:graph current-state)
          date-string (:date-string d)
          day-nodes (gq/get-nodes-for-day g {:date-string date-string})
          day-nodes-attrs (map #(uber/attrs g %) day-nodes)
          day-stats {:date-string date-string
                     :photo-cnt   (count (filter :img-file day-nodes-attrs))
                     :audio-cnt   (count (filter :audio-file day-nodes-attrs))
                     :video-cnt   (count (filter :video-file day-nodes-attrs))}]
      [date-string day-stats])))

(defn res-count [state query]
  (let [res (gq/extract-sorted2 state (merge {:n Integer/MAX_VALUE} query))]
    (count (set res))))

(defn completed-count [current-state]
  (let [q1 {:tags #{"#task" "#done"} :n Integer/MAX_VALUE}
        q2 {:tags #{"#task"} :opts #{":done"} :n Integer/MAX_VALUE}
        res1 (set (gq/extract-sorted2 current-state q1))
        res2 (set (gq/extract-sorted2 current-state q2))]
    (count (set/union res1 res2))))

(defn get-stats-fn
  "Retrieves stats of specified type. Picks the appropriate mapper function
   for the requested message type."
  [{:keys [current-state msg-payload msg-meta put-fn]}]
  (let [stats-type (:type msg-payload)
        path [:last-stat stats-type]
        last-gen (get-in current-state path 0)]
    (when (> (- (st/now) last-gen) 500)
      (let [start (st/now)
            stats-mapper (case stats-type
                           :stats/custom-fields cf/custom-fields-mapper
                           :stats/git-commits g/git-mapper
                           :stats/media media-mapper
                           nil)
            days (:days msg-payload)
            stats (when stats-mapper
                    (let [res (mapv (stats-mapper current-state) days)]
                      (into {} res)))]
        (info stats-type (count (str stats)))
        (if stats
          (put-fn (with-meta [:stats/result {:stats stats
                                             :type  stats-type}] msg-meta))
          (warn "No mapper defined for" stats-type))
        (info "completed get-stats" stats-type "in" (- (st/now) start) "ms"))
      {:new-state (assoc-in current-state path (st/now))})))

(def started-tasks
  {:tags     #{"#task"}
   :not-tags #{"#done" "#backlog" "#closed"}
   :opts     #{":started"}})

(def waiting-habits
  {:tags #{"#habit"}
   :opts #{":waiting"}})

(defn map-w-names [items ks]
  (into {} (map (fn [[ts st]]
                  [ts (select-keys st (set/union ks #{:timestamp}))])
                items)))

(defn make-stats-tags
  "Generate stats and tags from current-state."
  [state]
  {:hashtags      (gq/find-all-hashtags state)
   :pvt-hashtags  (gq/find-all-pvt-hashtags state)
   :pvt-displayed (:pvt-displayed (:cfg state))
   :mentions      (gq/find-all-mentions state)
   :stories       (map-w-names
                    (gq/find-all-stories state) #{:story-name :linked-saga})
   :sagas         (map-w-names (gq/find-all-sagas state) #{:saga-name})
   :cfg           (merge (:cfg state) {:pid (pid/current)})})

(defn count-words
  "Count total number of words."
  [current-state]
  (let [g (:graph current-state)
        entries (map #(uber/attrs g %) (:sorted-entries current-state))
        counts (map (fn [entry] (u/count-words entry)) entries)]
    (apply + counts)))

(defn count-words2
  "Count total number of words."
  [current-state]
  (let [g (:graph current-state)
        counts (pmap #(u/count-words (uber/attrs g %))
                     (:sorted-entries current-state))]
    (apply + counts)))

(defn hours-logged
  "Count total hours logged."
  [current-state]
  (let [g (:graph current-state)
        entries (map #(uber/attrs g %) (:sorted-entries current-state))
        seconds-logged (map (fn [entry]
                              (let [completed (get entry :completed-time 0)
                                    manual (gq/summed-durations entry)
                                    summed (+ completed manual)]
                                summed))
                            entries)
        total-seconds (apply + seconds-logged)
        total-hours (/ total-seconds 60 60)]
    total-hours))

(defn get-stats-fn2
  "Generates stats and tags (they only change on insert anyway) and initiates
   publication thereof to all connected clients."
  [{:keys [current-state put-fn msg-meta]}]
  (let [path [:last-stat :stats2 (:sente-uid msg-meta)]
        last-vclock (:global-vclock current-state)]
    (when (not= last-vclock (get-in current-state path))
      (let [start (st/now)
            aw {:award-points (aw/award-points current-state)}
            q {:questionnaires (q/questionnaires current-state)}
            uid (:sente-uid msg-meta)]
        (put-fn (with-meta [:stats/result2 aw] {:sente-uid uid}))
        (put-fn (with-meta [:stats/result2 q] {:sente-uid uid}))
        (info "completed stats2" "in" (- (st/now) start) "ms"))
      {:new-state (assoc-in current-state path last-vclock)})))

(def stats-handler-map
  {:stats/get  get-stats-fn
   :stats/get2 get-stats-fn2})
