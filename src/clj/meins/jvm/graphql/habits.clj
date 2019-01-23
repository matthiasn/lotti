(ns meins.jvm.graphql.habits
  (:require [meins.jvm.graph.query :as gq]
            [taoensso.timbre :refer [info error warn debug]]
            [meins.jvm.graphql.custom-fields :as cf]
            [ubergraph.core :as uc]
            [meins.jvm.datetime :as dt]
            [meins.common.utils.misc :as m]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.jvm.graph.stats.day :as gsd]
            [meins.common.utils.misc :as um]))

(def d (* 24 60 60 1000))

(defn success? [day nodes cmp-state [idx c]]
  (let [state @cmp-state
        g (:graph state)]
    (case (:type c)

      :min-max-sum
      (let [tag (:cf-tag c)
            k (:cf-key c)
            m (cf/custom-fields-mapper2 cmp-state tag)
            res (m day nodes)
            min-val (:min-val c)
            max-val (:max-val c)
            x (:v (k res))]
        {:success (when (number? x)
                    (and (if (number? min-val) (>= x min-val) true)
                         (if (number? max-val) (<= x max-val) true)))
         :idx     idx
         :v       x})

      :min-max-time
      (let [{:keys [story min-time max-time]} c
            stories (gq/find-all-stories state)
            sagas (gq/find-all-sagas state)
            day-stats (gsd/day-stats g nodes [] stories sagas day)
            actual (get-in day-stats [:by_story_m story] 0)]
        {:success (when (number? actual)
                    (and (if (number? min-time) (>= actual (* 60 min-time)) true)
                         (if (number? max-time) (<= actual (* 60 max-time)) true)))
         :idx     idx
         :v       actual})

      :questionnaire
      (let [{:keys [quest-k req-n]} c
            q-nodes (filter #(get-in % [:questionnaires quest-k]) nodes)
            res (count q-nodes)]
        {:success (<= req-n res)
         :idx     idx
         :v       res})

      false)))

(defn habit-success [habit [day nodes] state]
  (try
    (let [habit-ts (:timestamp habit)
          path [:stats-cache :days day :habits habit-ts]]
      (or (get-in @state path)
          (let [success? (partial success? day nodes state)
                versions (-> habit :habit :versions)
                version (->> versions
                             (filter (fn [[k v]]
                                       (> (compare day (:valid_from v)) -1)))
                             (sort-by first)
                             last
                             first)
                criteria (m/idxd (get-in versions [version :criteria]))
                by-criterion (mapv success? criteria)
                res {:success    (every? #(true? (:success %)) by-criterion)
                     :day        day
                     :habit_ts   habit-ts
                     :habit_text (:text habit)
                     :values     by-criterion}]
            (swap! state assoc-in path res)
            res)))
    (catch Exception ex (error ex))))

(defn habits-success [state context args value]
  (try
    (let [days (range (:days args 5))
          offset (* (:offset args 0) 24 60 60 1000)
          now (stc/now)
          pvt (:pvt args)
          g (:graph @state)
          day-mapper #(dt/ts-to-ymd (+ (- now (* % d)) offset))
          days-nodes (map (fn [day]
                            (let [nodes (gq/get-nodes-for-day g {:date_string day})]
                              [day (map #(uc/attrs g %) nodes)]))
                          (mapv day-mapper days))
          habits (gq/find-all-habits @state)
          pvt-filter (um/pvt-filter (:options @state))
          habits (if pvt habits (filter pvt-filter habits))
          f (fn [habit]
              (let [completed (when (:active (:habit habit))
                                (mapv #(habit-success habit % state) days-nodes))]
                {:completed   completed
                 :habit_entry habit}))
          res (mapv f habits)]
      res)
    (catch Exception ex (error ex))))

(defn habits-success-by-day [state context args value]
  (try
    (let [args (merge args (-> context :msg-payload :new-args))
          {:keys [day_strings pvt]} args
          g (:graph @state)
          days-nodes (map (fn [day]
                            (let [nodes (gq/get-nodes-for-day g {:date_string day})]
                              [day (map #(uc/attrs g %) nodes)]))
                          day_strings)
          habits (gq/find-all-habits @state)
          pvt-filter (um/pvt-filter (:options @state))
          habits (if pvt habits (filter pvt-filter habits))
          f (fn [habit]
              (when (:active (:habit habit))
                (mapv #(habit-success habit % state) days-nodes)))
          res (mapcat f habits)]
      res)
    (catch Exception ex (error ex))))


(defn waiting-habits [state context args value]
  (let [q {:tags #{"#habit"}
           :opts #{":waiting"}
           :n    100
           :pvt  (:pvt args)}
        current-state @state
        g (:graph current-state)
        habits (filter identity (gq/get-filtered2 current-state q))
        habits (mapv #(gq/entry-w-story g %) habits)]
    habits))
