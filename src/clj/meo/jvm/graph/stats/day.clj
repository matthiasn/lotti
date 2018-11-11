(ns meo.jvm.graph.stats.day
  "Get day stats from graph."
  (:require [meo.jvm.graph.query :as gq]
            [clj-time.format :as ctf]
            [ubergraph.core :as uc]
            [taoensso.timbre :refer [info error warn]]
            [camel-snake-kebab.core :refer [->snake_case]]
            [camel-snake-kebab.extras :refer [transform-keys]]
            [meo.jvm.datetime :as dt]
            [clj-time.coerce :as c]
            [meo.common.utils.misc :as u]))

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
  (let [manual (gq/summed-durations entry)]
    (if-let [for-day (:for_day entry)]
      (let [ymd (subs for-day 0 10)]
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

(defn day-stats [g nodes stories sagas date-string]
  (let [story-reducer (fn [acc entry]
                        (let [comment-for (:comment_for entry)
                              parent (when (and comment-for
                                                (uc/has-node? g comment-for))
                                       (uc/attrs g comment-for))
                              story (or (:primary_story parent)
                                        (:primary_story entry)
                                        0)
                              acc-time (or (get acc story) 0)
                              completed (or (get entry :completed_time) 0)
                              manual (manually-logged entry date-string)
                              summed (+ acc-time completed manual)]
                          (if (pos? summed)
                            (assoc-in acc [story] summed)
                            acc)))
        by-ts-mapper (fn [entry]
                       (let [{:keys [timestamp comment_for primary_story md
                                     text for_day]} entry
                             parent (when (and comment_for
                                               (uc/has-node? g comment_for))
                                      (uc/attrs g comment_for))
                             story-id (or (:primary_story parent)
                                          primary_story
                                          :no-story)
                             story (get-in stories [story-id])
                             for-ts (when for_day
                                      (let [dt (ctf/parse dt/dt-local-fmt for_day)]
                                        (c/to-long dt)))
                             adjusted-ts (:adjusted_ts entry)
                             saga (get sagas (:linked_saga story))
                             completed (or (get entry :completed_time) 0)
                             manual (manually-logged entry date-string)
                             summed (+ completed manual)]
                         (when (pos? summed)
                           {:story       (when story
                                           (assoc-in story [:saga] saga))
                            :timestamp   timestamp
                            :adjusted_ts (or adjusted-ts for-ts)
                            :md          md
                            :text        text
                            :comment_for comment_for
                            :parent      parent
                            :completed   completed
                            :summed      summed
                            :manual      manual})))
        by-story (reduce story-reducer {} nodes)
        by-ts (filter identity (map by-ts-mapper nodes))
        total (apply + (map second by-story))
        by-story-list (map (fn [[k v]]
                        (let [story (merge (get stories k) {:timestamp k})
                              saga (get sagas (:linked_saga story))]
                          {:logged v
                           :story  (assoc-in story [:linked_saga] saga)}))
                      by-story)]
    (merge
      (tasks nodes)
      {:day         date-string
       :total_time  total
       :word_count  (wordcount nodes)
       :entry_count (count nodes)
       :by_ts       by-ts
       :by_story_m  by-story
       :by_story    by-story-list})))
