(ns meo.jvm.graphql.habits
  (:require [meo.jvm.graph.query :as gq]
            [taoensso.timbre :refer [info error warn debug]]
            [meo.jvm.graph.stats.custom-fields :as cf]
            [ubergraph.core :as uc]
            [meo.jvm.datetime :as dt]
            [matthiasn.systems-toolbox.component :as stc]
            [meo.jvm.graph.stats.day :as gsd]))

(def d (* 24 60 60 1000))

(defn habit-success [habit day state]
  (let [g (:graph state)
        successful? (fn [c]
                      (case (:type c)

                        :min-max-sum
                        (let [tag (:cf-tag c)
                              k (:cf-key c)
                              m (cf/custom-fields-mapper state tag)
                              res (m day)
                              min-val (:min-val c)
                              max-val (:max-val c)
                              x (k res)]
                          (and (if (number? min-val) (>= x min-val) true)
                               (if (number? max-val) (<= x max-val) true)))

                        :min-max-time
                        (let [{:keys [story min-time max-time]} c
                              stories (gq/find-all-stories state)
                              sagas (gq/find-all-sagas state)
                              day-nodes (gq/get-nodes-for-day g {:date_string day})
                              day-nodes-attrs (map #(uc/attrs g %) day-nodes)
                              day-stats (gsd/day-stats g day-nodes-attrs stories sagas day)
                              actual (get-in day-stats [:by_story_m story] 0)]
                          (and (if (number? min-time) (>= actual (* 60 min-time)) true)
                               (if (number? max-time) (<= actual (* 60 max-time)) true)))

                        false))
        by-criterion (mapv successful? (-> habit :habit :criteria))]
    (every? true? by-criterion)))

(defn habits-success [state context args value]
  (try (let [days (range (:days args 5))
             now (stc/now)
             day-strings (mapv #(dt/ts-to-ymd (- now (* % d))) days)
             habits (filter #(-> % :habit :active)
                            (vals (gq/find-all-habits @state)))
             f (fn [habit]
                 {:completed   (mapv #(habit-success habit % @state) day-strings)
                  :habit_entry habit})
             res (mapv f habits)]
         res)
       (catch Exception ex (error ex))))
