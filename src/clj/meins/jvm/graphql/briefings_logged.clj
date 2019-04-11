(ns meins.jvm.graphql.briefings-logged
  "GraphQL query component"
  (:require [taoensso.timbre :refer [info error warn debug]]
            [meins.jvm.graphql.common :as gc]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.jvm.graph.query :as gq]
            [camel-snake-kebab.core :refer [->kebab-case-keyword ->snake_case]]
            [camel-snake-kebab.extras :refer [transform-keys]]
            [meins.jvm.graph.stats.day :as gsd]
            [meins.jvm.datetime :as dt]
            [clojure.set :as set]
            [meins.jvm.graphql.tasks :as gt]))

(def d (* 24 60 60 1000))

(defn completed-for-day [state day]
  (let [g (:graph state)
        entries (set/intersection
                  (gq/get-nodes-for-day g {:date_string day})
                  (set/union
                    (gq/get-done g :done)
                    (gq/get-done g :closed)))]
    (->> entries
         (map #(gq/entry-w-story state (gq/get-entry-xf state %)))
         (map gt/cfg-mapper)
         (filter :timestamp)
         (set))))

(defn briefing [state context args value]
  (let [g (:graph @state)
        d (:day args)
        ts (first (gq/get-briefing-for-day g {:briefing d}))]
    (when-let [briefing (gq/get-entry-xf @state ts)]
      (let [briefing (gc/linked-for @state briefing)
            linked-completed (fn [xs]
                               (let [xs (map gt/cfg-mapper xs)]
                                 (vec (set/union (set xs) (completed-for-day @state d)))))
            briefing (update-in briefing [:linked] linked-completed)
            briefing (update-in briefing [:linked] #(gc/distinct-by :timestamp %))
            comments (:comments (gq/get-comments briefing g ts))
            comments (mapv #(update-in (gq/get-entry-xf @state %) [:questionnaires :pomo1] vec)
                           comments)
            briefing (merge briefing {:comments comments
                                      :day      d})]
        briefing))))

(defn day-nodes [state day]
  (let [g (:graph state)
        nodes (gq/get-nodes-for-day g {:date_string day})]
    (map #(gq/get-entry state %) nodes)))

(defn logged-time [state context args value]
  (let [day (:day args)
        current-state @state
        stories (gq/find-all-stories current-state)
        sagas (gq/find-all-sagas current-state)
        nodes (day-nodes current-state day)
        prev-nodes (day-nodes current-state (dt/days-before day 1))
        next-nodes (day-nodes current-state (dt/days-before day -1))
        cal-nodes (set (concat prev-nodes next-nodes))
        day-stats (gsd/day-stats current-state nodes cal-nodes stories sagas day)]
    day-stats))

(defn day-stats [state context args value]
  (let [current-state @state
        g (:graph current-state)
        stories (gq/find-all-stories current-state)
        sagas (gq/find-all-sagas current-state)
        days (reverse (range (:days args 90)))
        now (stc/now)
        day-strings (mapv #(dt/ymd (- now (* % d))) days)
        f (fn [day]
            (let [day-nodes (gq/get-nodes-for-day g {:date_string day})
                  day-nodes-attrs (map #(gq/get-entry current-state %) day-nodes)]
              (gsd/day-stats current-state day-nodes-attrs [] stories sagas day)))
        stats (mapv f day-strings)]
    stats))
