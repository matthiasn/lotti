(ns meo.jvm.graphql.misc-stats
  "GraphQL query component"
  (:require [taoensso.timbre :refer [info error warn debug]]
            [matthiasn.systems-toolbox.component :as stc]
            [meo.jvm.graph.stats :as gs]
            [meo.jvm.graph.query :as gq]
            [meo.common.utils.parse :as p]
            [camel-snake-kebab.core :refer [->kebab-case-keyword ->snake_case]]
            [camel-snake-kebab.extras :refer [transform-keys]]
            [meo.jvm.datetime :as dt]
            [meo.jvm.graph.stats.custom-fields :as cf]
            [meo.jvm.graph.stats.git :as g]
            [meo.jvm.graph.stats.questionnaires :as q]
            [meo.jvm.graph.stats.awards :as aw]))

(def d (* 24 60 60 1000))

(defn match-count [state context args value]
  (gs/res-count @state (p/parse-search (:query args))))

(defn custom-field-stats [state context args value]
  (let [{:keys [days tag]} args
        days (reverse (range days))
        now (stc/now)
        custom-fields-mapper (cf/custom-fields-mapper @state tag)
        day-strings (mapv #(dt/ts-to-ymd (- now (* % d))) days)
        stats (mapv custom-fields-mapper day-strings)]
    stats))

(defn bp-field-stats [state context args value]
  (let [{:keys [days]} args
        from (- (stc/now) (* days d))
        q (merge (p/parse-search "#BP"))
        nodes (:entries-list (gq/get-filtered @state q))
        f (fn [entry] {:timestamp    (:timestamp entry)
                       :bp_systolic  (get-in entry [:custom_fields "#BP" :bp_systolic])
                       :bp_diastolic (get-in entry [:custom_fields "#BP" :bp_diastolic])})
        bp-entries (mapv f nodes)
        filtered (->> bp-entries
                      (filter #(every? identity (vals %)))
                      (filter #(> (:timestamp %) from)))]
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
  (let [{:keys [days tag k]} args
        newer-than (- (stc/now) (* d (or days 90)))
        stats (q/questionnaires-by-tag @state tag (keyword k))
        stats (filter #(:score %) stats)
        stats (vec (filter #(> (:timestamp %) newer-than) stats))]
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
