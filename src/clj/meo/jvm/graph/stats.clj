(ns meo.jvm.graph.stats
  "Get stats from graph."
  (:require [ubergraph.core :as uber]
            [meo.jvm.graph.query :as gq]
            [meo.jvm.graph.stats.awards :as aw]
            [meo.jvm.graph.stats.time :as t-s]
            [meo.jvm.graph.stats.location :as sl]
            [meo.jvm.graph.stats.questionnaires :as q]
            [meo.jvm.graph.stats.custom-fields :as cf]
            [meo.common.utils.misc :as u]
            [taoensso.timbre :refer [info error warn]]
            [clojure.set :as set]
            [clj-pid.core :as pid]))

(defn tasks-mapper
  "Create mapper function for task stats"
  [current-state]
  (fn [d]
    (let [g (:graph current-state)
          date-string (:date-string d)
          day-nodes (gq/get-nodes-for-day g {:date-string date-string})
          day-nodes-attrs (map #(uber/attrs g %) day-nodes)
          task-nodes (filter #(contains? (:tags %) "#task") day-nodes-attrs)
          done-nodes (filter #(contains? (:tags %) "#done") day-nodes-attrs)
          closed-nodes (filter #(contains? (:tags %) "#closed") day-nodes-attrs)
          day-stats {:date-string date-string
                     :tasks-cnt   (count task-nodes)
                     :done-cnt    (count done-nodes)
                     :closed-cnt  (count closed-nodes)}]
      [date-string day-stats])))

(defn wordcount-mapper
  "Create mapper function for wordcount stats"
  [current-state]
  (fn [d]
    (let [g (:graph current-state)
          date-string (:date-string d)
          day-nodes (gq/get-nodes-for-day g {:date-string date-string})
          day-nodes-attrs (map #(uber/attrs g %) day-nodes)
          counts (map (fn [entry] (u/count-words entry)) day-nodes-attrs)
          day-stats {:date-string date-string
                     :word-count  (apply + counts)
                     :entry-count (count day-nodes)}]
      [date-string day-stats])))

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
  (future
    (let [stats-type (:type msg-payload)
          stats-mapper (case stats-type
                         :stats/pomodoro t-s/time-mapper
                         :stats/custom-fields cf/custom-fields-mapper
                         :stats/tasks tasks-mapper
                         :stats/wordcount wordcount-mapper
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
        (warn "No mapper defined for" stats-type))))
  {})

(defn get-basic-stats [state]
  {:entry-count (count (:sorted-entries state))
   :import-cnt  (res-count state {:tags #{"#import"}})
   :locations   (sl/locations state)})

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
   ;:locations     (gq/find-all-locations state)
   :cfg           (merge (:cfg state) {:pid (pid/current)})})

(defn count-words
  "Count total number of words."
  [current-state]
  (let [g (:graph current-state)
        entries (map #(uber/attrs g %) (:sorted-entries current-state))
        counts (map (fn [entry] (u/count-words entry)) entries)]
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

(defn stats-tags-fn
  "Generates stats and tags (they only change on insert anyway) and initiates
   publication thereof to all connected clients."
  [{:keys [current-state put-fn msg-meta] :as msg-map}]
  (future
    (let [stats-tags (make-stats-tags current-state)
          uid (:sente-uid msg-meta)]
      (put-fn (with-meta [:state/stats-tags stats-tags] {:sente-uid uid}))))
  (future
    (let [stats {:started-tasks (gq/get-filtered current-state started-tasks)}
          uid (:sente-uid msg-meta)]
      (put-fn (with-meta [:state/stats-tags2 stats] {:sente-uid uid}))))
  (future
    (let [stats {:waiting-habits (gq/get-filtered current-state waiting-habits)}
          uid (:sente-uid msg-meta)]
      (put-fn (with-meta [:state/stats-tags2 stats] {:sente-uid uid}))))
  (future
    (let [stats {:word-count (count-words current-state)}
          uid (:sente-uid msg-meta)]
      (put-fn (with-meta [:stats/result2 stats] {:sente-uid uid}))))
  (future
    (let [stats {:hours-logged (hours-logged current-state)}
          uid (:sente-uid msg-meta)]
      (put-fn (with-meta [:stats/result2 stats] {:sente-uid uid}))))
  (future
    (let [stats {:briefings (gq/find-all-briefings current-state)}
          uid (:sente-uid msg-meta)]
      (put-fn (with-meta [:state/stats-tags2 stats] {:sente-uid uid}))))
  {})

(defn task-summary-stats
  "Generate some very basic stats about the graph for display in UI."
  [state k]
  (case k
    :open-tasks-cnt (res-count state {:tags     #{"#task"}
                                      :not-tags #{"#done" "#backlog" "#closed"}})
    :backlog-cnt (res-count state {:tags     #{"#task" "#backlog"}
                                   :not-tags #{"#done" "#closed"}})
    :completed-cnt (completed-count state)
    :closed-cnt (res-count state {:tags #{"#task" "#closed"}})))

(defn task-summary-stats-w
  "Generate some very basic stats about the graph for display in UI."
  [state k msg-meta put-fn]
  (future
    (let [res (task-summary-stats state k)]
      (put-fn (with-meta [:stats/result2 {k res}] msg-meta)))))

(defn get-stats-fn2
  "Generates stats and tags (they only change on insert anyway) and initiates
   publication thereof to all connected clients."
  [{:keys [current-state put-fn msg-meta]}]
  (future
    (let [stats (get-basic-stats current-state)
          uid (:sente-uid msg-meta)]
      (put-fn (with-meta [:stats/result2 stats] {:sente-uid uid}))))
  (task-summary-stats-w current-state :open-tasks-cnt msg-meta put-fn)
  (task-summary-stats-w current-state :backlog-cnt msg-meta put-fn)
  (task-summary-stats-w current-state :completed-cnt msg-meta put-fn)
  (task-summary-stats-w current-state :closed-cnt msg-meta put-fn)
  (future
    (let [stats {:award-points (aw/award-points current-state)}
          uid (:sente-uid msg-meta)]
      (put-fn (with-meta [:stats/result2 stats] {:sente-uid uid}))))
  (future
    (let [stats {:questionnaires (q/questionnaires current-state)}
          uid (:sente-uid msg-meta)]
      (put-fn (with-meta [:stats/result2 stats] {:sente-uid uid}))))
  {})

(def stats-handler-map
  {:stats/get            get-stats-fn
   :stats/get2           get-stats-fn2
   :state/stats-tags-get stats-tags-fn})