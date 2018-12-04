(ns meo.jvm.graphql.custom-fields
  (:require [meo.jvm.graph.query :as gq]
            [taoensso.timbre :refer [info error warn debug]]))

(defn custom-fields-cfg
  "Generates the custom custom fields config map as required by the
   user interface. The usage of custom fields in the UI predates the
   definition of custom fields in a specialized entry. The data
   format should be adjusted subsequently."
  [state]
  (debug "custom-fields-cfg")
  (let [q {:tags #{"#custom-field-cfg"}
           :n    Integer/MAX_VALUE}
        res (:entries-list (gq/get-filtered state q))
        f (fn [entry]
            (let [{:keys [tag items pvt]} (:custom_field_cfg entry)
                  story (:primary_story entry)
                  fm (fn [field]
                       (let [k (keyword (:name field))
                             label (:label field)]
                         [k {:cfg   field
                             :label label}]))
                  fields (into {} (map fm items))]
              [tag {:default-story story
                    :timestamp     (:timestamp entry)
                    :pvt           pvt
                    :fields        fields}]))
        res (->> (map f res)
                 (sort-by #(:timestamp (second %)))
                 (filter first)
                 reverse
                 (into {}))]
    (debug "custom-fields-cfg" res)
    res))
