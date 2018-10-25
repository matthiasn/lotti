(ns meo.jvm.graphql.habits
  (:require [meo.jvm.graph.query :as gq]
            [taoensso.timbre :refer [info error warn debug]]
            [meo.jvm.graph.stats.custom-fields :as cf]
            [meo.jvm.datetime :as dt]
            [matthiasn.systems-toolbox.component :as stc]))

(def d (* 24 60 60 1000))
#_#_(defn habit-success [habit day state]
      (let [successful? (fn [c]
                          (when (= (:type c) :min-max-sum)
                            (let [tag (:cf-tag c)
                                  k (:cf-key c)
                                  m (cf/custom-fields-mapper state tag)
                                  res (m day)
                                  min-val (:min-val c)
                                  x (k res)]
                              (when (and k c (number? x) (number? min-val))
                                (>= x min-val)))))
            by-criterion (mapv successful? (-> habit :habit :criteria))]
        {:habit_entry habit
         :completed   (every? true? by-criterion)}))

    (defn habits-success [state context args value]
      (try (let [days (range (:days args 5))
                 now (stc/now)
                 day-strings (mapv #(dt/ts-to-ymd (- now (* % d))) days)
                 habits (filter #(-> % :habit :active)
                                (vals (gq/find-all-habits @state)))
                 by-day (fn [day] {:habits (map #(habit-success % day @state) habits)
                                   :day    day})]
             (map by-day day-strings))
           (catch Exception ex (error ex))))


(defn habit-success [habit day state]
  (let [successful? (fn [c]
                      (when (= (:type c) :min-max-sum)
                        (let [tag (:cf-tag c)
                              k (:cf-key c)
                              m (cf/custom-fields-mapper state tag)
                              res (m day)
                              min-val (:min-val c)
                              x (k res)]
                          (when (and k c (number? x) (number? min-val))
                            (>= x min-val)))))
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
         (info res)
         res)
       (catch Exception ex (error ex))))
