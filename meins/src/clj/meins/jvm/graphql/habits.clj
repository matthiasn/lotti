(ns meins.jvm.graphql.habits
  (:require [matthiasn.systems-toolbox.component :as stc]
            [meins.common.habits.util :as hu]
            [meins.common.utils.misc :as um]
            [meins.jvm.datetime :as dt]
            [meins.jvm.graph.query :as gq]
            [meins.jvm.graph.stats.day :as gsd]
            [meins.jvm.graphql.custom-fields :as cf]
            [taoensso.timbre :refer [debug error info warn]]))

(def d (* 24 60 60 1000))

(defn success? [day nodes cmp-state [idx c]]
  (let [state @cmp-state]
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
      (let [{:keys [story saga min-time max-time]} c
            stories (gq/find-all-stories state)
            sagas (gq/find-all-sagas state)
            day-stats (gsd/day-stats state nodes [] stories sagas day)
            actual-by-story (get-in day-stats [:by_story_m story] 0)
            actual-by-saga (get-in day-stats [:by_saga_m saga] 0)
            actual (if (number? story) actual-by-story actual-by-saga)]
        {:success (and (if (number? min-time) (>= actual (* 60 min-time)) true)
                       (if (number? max-time) (<= actual (* 60 max-time)) true)
                       (or (number? min-time) (number? max-time)))
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
                criteria (um/idxd (hu/get-criteria habit day))
                by-criterion (mapv success? criteria)
                res {:success    (every? #(true? (:success %)) by-criterion)
                     :day        day
                     :habit_ts   habit-ts
                     :habit_text (:text habit)
                     :values     by-criterion}]
            (swap! state assoc-in path res)
            res)))
    (catch Exception ex (error ex))))

(defn habits-success [state _context args _value]
  (try
    (let [days (range (:days args 5))
          offset (* (:offset args 0) 24 60 60 1000)
          now (stc/now)
          pvt (:pvt args)
          g (:graph @state)
          day-mapper #(dt/ymd (+ (- now (* % d)) offset))
          days-nodes (map (fn [day]
                            (let [nodes (gq/get-nodes-for-day g {:date_string day})]
                              [day (map #(gq/get-entry @state %) nodes)]))
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

(defn habits-success-by-day [state context args _value]
  (try
    (let [args (merge args (-> context :msg-payload :new-args))
          {:keys [day_strings pvt]} args
          g (:graph @state)
          days-nodes (map (fn [day]
                            (let [nodes (gq/get-nodes-for-day g {:date_string day})]
                              [day (map #(gq/get-entry @state %) nodes)]))
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


(defn waiting-habits [state _context args _value]
  (let [q {:tags #{"#habit"}
           :opts #{":waiting"}
           :n    100
           :pvt  (:pvt args)}
        current-state @state
        habits (filter identity (gq/get-filtered2 current-state q))
        habits (mapv #(gq/entry-w-story current-state %) habits)]
    habits))
