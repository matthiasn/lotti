(ns meins.jvm.graphql.misc-stats
  "GraphQL query component"
  (:require [matthiasn.systems-toolbox.component :as stc]
            [meins.common.utils.parse :as p]
            [meins.jvm.datetime :as dt]
            [meins.jvm.graph.query :as gq]
            [meins.jvm.graph.stats :as gs]
            [meins.jvm.graph.stats.awards :as aw]
            [meins.jvm.graph.stats.git :as g]
            [meins.jvm.graph.stats.questionnaires :as q]
            [taoensso.timbre :refer [debug error info warn]]))

(def d (* 24 60 60 1000))

(defn match-count [state _context args _value]
  (gs/res-count @state (p/parse-search (:query args))))

(defn bp-field-stats [state _context args _value]
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

(defn git-stats [state _context args _value]
  (let [{:keys [days]} args
        days (reverse (range days))
        now (stc/now)
        git-mapper (g/git-mapper @state)
        day-strings (mapv #(dt/ymd (- now (* % d))) days)
        stats (mapv git-mapper day-strings)]
    (debug stats)
    stats))

(defn questionnaires [state _context args _value]
  (let [{:keys [days tag k offset]} args
        newer-than (- (stc/now) (* d (or (+ days (* -1 offset)) 90)))
        older-than (- (stc/now) (* d (* -1 offset) 0))
        stats (q/questionnaires-by-tag @state tag (keyword k))
        stats (filter #(:score %) stats)
        stats (vec (filter #(> (:timestamp %) newer-than) stats))
        stats (vec (filter #(< (:timestamp %) older-than) stats))]
    (debug stats)
    stats))

(defn questionnaires-by-days [state context args _value]
  (let [args (merge args (-> context :msg-payload :new-args))
        {:keys [day_strings tag k]} args
        f #(q/questionnaires-by-tag-day @state tag % (keyword k))
        stats (mapcat f day_strings)
        stats (filter #(:score %) stats)]
    (debug stats)
    stats))

(defn award-points [state _context args _value]
  (let [{:keys [days]} args
        newer-than (dt/ymd (- (stc/now) (* d (or days 90))))
        stats (aw/award-points @state)
        sort-filter (fn [k]
                      (sort-by first (filter #(pos? (compare (first %) newer-than))
                                             (k stats))))
        xf (fn [[k v]] (merge v {:date_string k}))
        sorted (assoc-in stats [:by-day] (mapv xf (sort-filter :by-day)))]
    (assoc-in sorted [:by-day-skipped] (mapv xf (sort-filter :by-day-skipped)))))
