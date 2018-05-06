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
    (if-let [for-day (:for-day entry)]
      (let [ymd (subs for-day 0 10)]
        (if (= date-string ymd) manual 0))
      manual)))

(defn wordcount [entries]
  (apply + (map (fn [entry] (u/count-words entry)) entries)))

(defn tasks [entries]
  (let [task-nodes (filter #(contains? (:tags %) "#task") entries)
        done-nodes (filter #(contains? (:tags %) "#done") entries)
        closed-nodes (filter #(contains? (:tags %) "#closed") entries)]
    {:tasks-cnt        (count task-nodes)
     :done-tasks-cnt   (count done-nodes)
     :closed-tasks-cnt (count closed-nodes)}))

(defn day-stats [g nodes stories sagas date-string]
  (let [story-reducer (fn [acc entry]
                        (let [comment-for (:comment-for entry)
                              parent (when (and comment-for
                                                (uc/has-node? g comment-for))
                                       (uc/attrs g comment-for))
                              story (or (:primary-story parent)
                                        (:primary-story entry)
                                        :no-story)
                              acc-time (get acc story 0)
                              completed (get entry :completed-time 0)
                              manual (manually-logged entry date-string)
                              summed (+ acc-time completed manual)]
                          (if (pos? summed)
                            (assoc-in acc [story] summed)
                            acc)))
        by-ts-mapper (fn [entry]
                       (let [{:keys [timestamp comment-for primary-story md
                                     text for-day]} entry
                             parent (when (and comment-for
                                               (uc/has-node? g comment-for))
                                      (uc/attrs g comment-for))
                             story-id (or (:primary-story parent)
                                          primary-story
                                          :no-story)
                             story (get-in stories [story-id])
                             for-ts (when for-day
                                      (let [dt (ctf/parse dt/dt-local-fmt for-day)]
                                        (c/to-long dt)))
                             ts (or for-ts timestamp)
                             saga (get-in sagas [(:linked-saga story)])
                             completed (get entry :completed-time 0)
                             manual (manually-logged entry date-string)
                             summed (+ completed manual)]
                         (when (pos? summed)
                           {:story       (when story
                                           (assoc-in story [:linked-saga] saga))
                            :timestamp   ts
                            :md          md
                            :text        text
                            :comment-for comment-for
                            :completed   completed
                            :summed      summed
                            :manual      manual})))
        by-story (reduce story-reducer {} nodes)
        by-ts (filter identity (map by-ts-mapper nodes))
        total (apply + (map second by-story))
        by-story (map (fn [[k v]]
                        (let [story (merge (get stories k) {:timestamp k})
                              saga (get sagas (:linked-saga story))]
                          {:logged v
                           :story  (assoc-in story [:linked-saga] saga)}))
                      by-story)]
    (merge
      (tasks nodes)
      {:day         date-string
       :total-time  total
       :word-count  (wordcount nodes)
       :entry-count (count nodes)
       :by-ts       by-ts
       :by-story    by-story})))
