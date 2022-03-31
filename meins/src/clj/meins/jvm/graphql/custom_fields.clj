(ns meins.jvm.graphql.custom-fields
  (:require [clj-time.core :as ct]
            [clj-time.format :as ctf]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.jvm.datetime :as dt]
            [meins.jvm.graph.query :as gq]
            [meins.jvm.graphql.common :as gc]
            [taoensso.timbre :refer [debug error info warn]]))

(defn custom-fields-cfg
  "Generates the custom fields config map as required by the
   user interface. The usage of custom fields in the UI predates the
   definition of custom fields in a specialized entry. The data
   format should be adjusted subsequently."
  [state]
  (debug "custom-fields-cfg")
  (let [q {:tags #{"#custom-field-cfg"}
           :n    Integer/MAX_VALUE}
        res (:entries-list (gq/get-filtered state q))
        f (fn [entry]
            (let [{:keys [tag items pvt active]} (:custom_field_cfg entry)
                  story (:primary_story entry)
                  fm (fn [field]
                       (let [k (keyword (:name field))
                             label (:label field)]
                         [k {:cfg   field
                             :label label}]))
                  fields (into {} (map fm items))]
              [tag {:default-story story
                    :timestamp     (:timestamp entry)
                    :adjusted_ts   (:adjusted_ts entry)
                    :pvt           pvt
                    :active        active
                    :fields        fields}]))
        res (->> (map f res)
                 (sort-by #(or (:adjusted_ts (second %))
                               (:timestamp (second %))))
                 (filter first)
                 reverse
                 (into {}))]
    (debug "custom-fields-cfg" res)
    res))


(def dtz (ct/default-time-zone))
(def fmt (ctf/formatter "yyyy-MM-dd'T'HH:mm" dtz))
(defn parse [dt] (ctf/parse fmt dt))

(defn bool-conv [x]
  (if (boolean? x)
    (if x 1 0)
    x))

(defn val-mapper [k field entry]
  (let [path [:custom_fields k field]
        ts (or (:adjusted_ts entry)
               (:timestamp entry))]
    {:v  (bool-conv (get-in entry path))
     :ts ts}))

(defn stats-mapper [tag nodes [k fields]]
  (let [field-mapper
        (fn [[field v]]
          (let [op (when (contains? #{:number :time :switch} (:type (:cfg v)))
                     (case (:agg (:cfg v))
                       :min #(when (seq %) (apply min (map :v %)))
                       :max #(when (seq %) (apply max (map :v %)))
                       :mean #(when (seq %) (double (/ (apply + (map :v %)) (count %))))
                       #(apply + (map :v %))))
                res (vec (filter #(:v %) (mapv (partial val-mapper k field) nodes)))]
            [field {:v   (if op
                           (try (op res)
                                (catch Exception e (error e res)))
                           res)
                    :vs  res
                    :tag tag}]))]
    (into {} (mapv field-mapper fields))))

(defn adjusted-ts-filter [date-string entry]
  (let [adjusted-ts (:adjusted_ts entry)
        tz (:timezone entry)]
    (or (not adjusted-ts)
        (= (dt/ts-to-ymd-tz adjusted-ts tz)
           date-string))))

(defn fields-mapper [[k {:keys [v tag vs]}]]
  {:field  (name k)
   :tag    tag
   :value  (bool-conv v)
   :values vs})

(defn custom-fields-mapper
  "Creates mapper function for custom field stats. Takes current state. Returns
   function that takes date string, such as '2016-10-10', and returns map with
   results for the defined custom fields, plus the date string. Performs
   operation specified for field, such as sum, min, max."
  [current-state tag]
  (let [custom-fields (custom-fields-cfg current-state)
        fields-def (into {} (map (fn [[k v]] [k (:fields v)])
                                 (select-keys custom-fields [tag])))
        g (:graph current-state)]
    (fn [date-string]
      (let [day-nodes (gq/get-nodes-for-day g {:date_string date-string})
            day-nodes-attrs (map #(gq/get-entry current-state %) day-nodes)
            nodes (filter :custom_fields day-nodes-attrs)
            nodes (filter (partial adjusted-ts-filter date-string) nodes)
            fields (mapv (partial stats-mapper tag nodes) fields-def)]
        (apply merge
               {:date_string date-string
                :fields      (mapv fields-mapper (first fields))
                :tag         tag}
               fields)))))

(defn custom-fields-mapper2
  "Creates mapper function for custom field stats. Takes current state. Returns
   function that takes date string, such as '2016-10-10', and returns map with
   results for the defined custom fields, plus the date string. Performs
   operation specified for field, such as sum, min, max."
  [cmp-state tag]
  (let [path [:stats-cache :custom-fields]
        custom-fields (or (get-in @cmp-state path)
                          (let [cfc (custom-fields-cfg @cmp-state)]
                            (swap! cmp-state assoc-in path cfc)
                            cfc))
        fields-def (into {} (map (fn [[k v]] [k (:fields v)])
                                 (select-keys custom-fields [tag])))]
    (fn [day nodes]
      (let [nodes (filter :custom_fields nodes)
            nodes (filter (partial adjusted-ts-filter day) nodes)
            fields (mapv (partial stats-mapper tag nodes) fields-def)]
        (apply merge
               {:date_string day
                :fields      (mapv fields-mapper (first fields))
                :tag         tag}
               fields)))))

(defn custom-field-stats [state _context args _value]
  (let [{:keys [days tag offset]} args
        offset (* offset 24 60 60 1000)
        days (reverse (range days))
        now (stc/now)
        custom-fields-mapper (custom-fields-mapper @state tag)
        day-mapper #(dt/ymd
                      (+ (- now (* % gc/d)) offset))
        day-strings (mapv day-mapper days)
        stats (mapv custom-fields-mapper day-strings)]
    stats))

(defn custom-field-stats-by-day [state _context args _value]
  (let [{:keys [day tag]} args
        custom-fields-fn (custom-fields-mapper @state tag)]
    (custom-fields-fn day)))

(defn custom-fields-by-days [state _context args _value]
  (let [{:keys [day_strings tags]} args
        tag-mapper (fn [tag] (mapv (custom-fields-mapper @state tag) day_strings))]
    (apply concat (map tag-mapper tags))))
