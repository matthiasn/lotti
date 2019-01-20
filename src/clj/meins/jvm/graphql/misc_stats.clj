(ns meins.jvm.graphql.misc-stats
  "GraphQL query component"
  (:require [taoensso.timbre :refer [info error warn debug]]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.jvm.graph.stats :as gs]
            [meins.jvm.graph.query :as gq]
            [meins.common.utils.parse :as p]
            [camel-snake-kebab.core :refer [->kebab-case-keyword ->snake_case]]
            [camel-snake-kebab.extras :refer [transform-keys]]
            [meins.jvm.datetime :as dt]
            [meins.jvm.graph.stats.git :as g]
            [meins.jvm.graph.stats.questionnaires :as q]
            [meins.jvm.graph.stats.awards :as aw]))

(def d (* 24 60 60 1000))

(defn match-count [state context args value]
  (gs/res-count @state (p/parse-search (:query args))))

(defn bp-field-stats [state context args value]
  (let [{:keys [days]} args
        from (- (stc/now) (* (+ days (* -1 (:offset args 0))) d))
        q (merge (p/parse-search "#BP"))
        nodes (:entries-list (gq/get-filtered @state q))
        f (fn [entry] {:timestamp    (:timestamp entry)
                       :adjusted_ts  (or (:adjusted_ts entry) (:timestamp entry))
                       :bp_systolic  (get-in entry [:custom_fields "#BP" :bp_systolic])
                       :bp_diastolic (get-in entry [:custom_fields "#BP" :bp_diastolic])})
        bp-entries (mapv f nodes)
        filtered (->> bp-entries
                      (filter #(every? identity (vals %)))
                      (filter #(or (> (:timestamp %) from)
                                   (> (:adjusted_ts %) from))))]
    filtered))

(defn git-stats [state context args value]
  (let [{:keys [days]} args
        days (reverse (range days))
        now (stc/now)
        git-mapper (g/git-mapper @state)
        day-strings (mapv #(dt/ts-to-ymd (- now (* % d))) days)
        stats (mapv git-mapper day-strings)]
    (debug stats)
    stats))

(defn questionnaires [state context args value]
  (let [{:keys [days tag k offset]} args
        newer-than (- (stc/now) (* d (or (+ days (* -1 offset)) 90)))
        older-than (- (stc/now) (* d (* -1 offset) 0))
        stats (q/questionnaires-by-tag @state tag (keyword k))
        stats (filter #(:score %) stats)
        stats (vec (filter #(> (:timestamp %) newer-than) stats))
        stats (vec (filter #(< (:timestamp %) older-than) stats))]
    (debug stats)
    stats))

(defn questionnaires-by-days [state context args value]
  (let [{:keys [day_strings tag k]} args
        f #(q/questionnaires-by-tag-day @state tag % (keyword k))
        stats (mapcat f day_strings)
        stats (filter #(:score %) stats)]
    (debug stats)
    stats))

(defn award-points [state context args value]
  (let [{:keys [days]} args
        newer-than (dt/ts-to-ymd (- (stc/now) (* d (or days 90))))
        stats (aw/award-points @state)
        sort-filter (fn [k]
                      (sort-by first (filter #(pos? (compare (first %) newer-than))
                                             (k stats))))
        xf (fn [[k v]] (merge v {:date_string k}))
        sorted (assoc-in stats [:by-day] (mapv xf (sort-filter :by-day)))]
    (assoc-in sorted [:by-day-skipped] (mapv xf (sort-filter :by-day-skipped)))))
