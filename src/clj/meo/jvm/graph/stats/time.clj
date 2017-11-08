(ns meo.jvm.graph.stats.time
  "Get stats from graph."
  (:require [ubergraph.core :as uber]
            [meo.jvm.graph.query :as gq]
            [clj-time.core :as t]
            [meo.jvm.graph.stats.awards :as aw]
            [meo.common.utils.misc :as u]
            [clj-time.format :as ctf]
            [matthiasn.systems-toolbox.log :as l]
            [clojure.tools.logging :as log]
            [ubergraph.core :as uc]
            [meo.jvm.datetime :as dt]
            [clj-time.coerce :as c]))

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

(defn time-by-stories
  "Calculate time spent per story, plus total time."
  [g nodes stories sagas date-string]
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
        by-ts-reducer (fn [acc entry]
                        (let [comment-for (:comment-for entry)
                              parent (when (and comment-for
                                                (uc/has-node? g comment-for))
                                       (uc/attrs g comment-for))
                              story-id (or (:primary-story parent)
                                           (:primary-story entry)
                                           :no-story)
                              story (get-in stories [story-id])
                              acc-time (get acc story-id 0)
                              for-ts (when-let [for-day (:for-day entry)]
                                       (let [dt (ctf/parse dt/dt-local-fmt for-day)]
                                         (c/to-long dt)))
                              ts (or for-ts (:timestamp entry))
                              saga-id (:linked-saga story)
                              saga (get-in sagas [saga-id])
                              completed (get entry :completed-time 0)
                              manual (manually-logged entry date-string)
                              summed (+ acc-time completed manual)]
                          (if (pos? summed)
                            (assoc-in acc [ts] {:story       story-id
                                                :timestamp   ts
                                                :comment-for comment-for
                                                :saga        saga-id
                                                :summed      summed
                                                :completed   completed
                                                :manual      manual})
                            acc)))
        by-story (reduce story-reducer {} nodes)
        by-ts (reduce by-ts-reducer {} nodes)]
    {:date-string   date-string
     :total-time    (apply + (map second by-story))
     :time-by-ts    by-ts
     :time-by-story by-story
     :time-by-saga  (time-by-sagas g by-story)}))

(defn time-mapper
  "Create mapper function for time stats"
  [current-state]
  (let [g (:graph current-state)
        stories (gq/find-all-stories {:graph g})
        sagas (gq/find-all-sagas {:graph g})]
    (fn [d]
      (let [date-string (:date-string d)
            day-nodes (gq/get-nodes-for-day g {:date-string date-string})
            day-nodes-attrs (map #(uber/attrs g %) day-nodes)
            day-stats (time-by-stories g day-nodes-attrs stories sagas date-string)]
        [date-string day-stats]))))
