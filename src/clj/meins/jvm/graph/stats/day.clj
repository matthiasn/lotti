(ns meins.jvm.graph.stats.day
  "Get day stats from graph."
  (:require [clj-time.coerce :as ctc]
            [clj-time.core :as ct]
            [clj-time.format :as ctf]
            [meins.common.utils.misc :as u]
            [meins.jvm.graph.query :as gq]
            [taoensso.timbre :refer [error info warn]]))

(defn time-by-sagas
  "Calculate time spent per saga, plus time not assigned to any saga."
  [g by-story]
  (let [stories (gq/find-all-stories {:graph g})
        saga-reducer (fn [acc [k v]]
                       (let [saga (get-in stories [k :linked-saga] :no-saga)]
                         (update-in acc [saga] #(+ v (or % 0)))))]
    (reduce saga-reducer {} by-story)))

(defn manually-logged
  "Calculates summed duration and returns it when entry is either not for a
   different day, or, if so, when date string from query is equal to the
   referenced day. Otherwise returns zero."
  [entry date-string]
  (let [manual (gq/summed-durations entry)
        local-fmt (ctf/with-zone (ctf/formatters :year-month-day)
                                 (ct/default-time-zone))]
    (if-let [adjusted-ts (:adjusted_ts entry)]
      (let [ymd (ctf/unparse local-fmt (ctc/from-long adjusted-ts))]
        (if (= date-string ymd) manual 0))
      manual)))

(defn wordcount [entries]
  (apply + (map (fn [entry] (u/count-words entry)) entries)))

(defn tasks [entries]
  (let [task-nodes (filter #(contains? (:tags %) "#task") entries)
        done-nodes (filter #(contains? (:tags %) "#done") entries)
        closed-nodes (filter #(contains? (:tags %) "#closed") entries)]
    {:tasks_cnt        (count task-nodes)
     :done_tasks_cnt   (count done-nodes)
     :closed_tasks_cnt (count closed-nodes)}))

(defn saga-reducer [date-string state stories sagas]
  (fn [acc entry]
    (let [comment-for (:comment_for entry)
          parent (gq/get-entry state comment-for)
          story-id (or (:primary_story parent)
                       (:primary_story entry)
                       0)
          story (get stories story-id)
          saga (get sagas (:linked_saga story))
          saga-id (:timestamp saga)
          acc-time (or (get acc saga-id) 0)
          completed (or (get entry :completed_time) 0)
          manual (manually-logged entry date-string)
          summed (+ acc-time completed manual)]
      (if (pos? summed)
        (assoc-in acc [saga-id] summed)
        acc))))

(defn day-stats [state nodes cal-nodes stories sagas date-string]
  (let [story-reducer (fn [acc entry]
                        (let [comment-for (:comment_for entry)
                              parent (gq/get-entry state comment-for)
                              story-id (or (:primary_story parent)
                                           (:primary_story entry)
                                           0)
                              acc-time (or (get acc story-id) 0)
                              completed (or (get entry :completed_time) 0)
                              manual (manually-logged entry date-string)
                              summed (+ acc-time completed manual)]
                          (if (pos? summed)
                            (assoc-in acc [story-id] summed)
                            acc)))
        saga-reducer (saga-reducer date-string state stories sagas)
        by-ts-mapper (fn [entry]
                       (let [{:keys [timestamp comment_for primary_story md
                                     text adjusted_ts]} entry
                             parent (gq/get-entry state comment_for)
                             story-id (or (:primary_story parent)
                                          primary_story
                                          :no-story)
                             story (get-in stories [story-id])
                             saga (get sagas (:linked_saga story))
                             completed (or (get entry :completed_time) 0)
                             manual (gq/summed-durations entry)
                             summed (+ completed manual)]
                         (when (pos? summed)
                           {:story       (when story
                                           (assoc-in story [:saga] saga))
                            :timestamp   timestamp
                            :adjusted_ts adjusted_ts
                            :md          md
                            :text        text
                            :comment_for comment_for
                            :parent      parent
                            :completed   completed
                            :summed      summed
                            :manual      manual})))
        by-story (reduce story-reducer {} nodes)
        by-ts (filter identity (map by-ts-mapper nodes))
        by-ts-cal (filter identity (map by-ts-mapper (concat nodes cal-nodes)))
        total (apply + (map second by-story))
        by-story-list (map (fn [[k v]]
                             (let [story (merge (get stories k) {:timestamp k})
                                   saga (get sagas (:linked_saga story))]
                               {:logged v
                                :story  (assoc-in story [:linked_saga] saga)}))
                           by-story)
        by-saga-m (reduce saga-reducer {} nodes)
        by-saga (map (fn [[k v]] {:logged v
                                  :saga   (get sagas k)})
                     by-saga-m)]
    (merge
      (tasks nodes)
      {:day         date-string
       :total_time  total
       :word_count  (wordcount nodes)
       :entry_count (count nodes)
       :by_ts       by-ts
       :by_ts_cal   by-ts-cal
       :by_story_m  by-story
       :by_saga_m   by-saga-m
       :by_saga     by-saga
       :by_story    by-story-list})))
