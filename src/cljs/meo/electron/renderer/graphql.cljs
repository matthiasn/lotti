(ns meo.electron.renderer.graphql
  (:require [venia.core :as v]
            [taoensso.timbre :refer-macros [info debug]]
            [clojure.string :as s]))

(defn graphql-query [days tags]
  (let [qfn (fn [t]
              {:query/data  [:custom_field_stats {:days days :tag t}
                             [:date_string [:fields [:field :value]]]]
               :query/alias (keyword (s/replace (subs t 1) "-" "_"))})
        queries (mapv qfn tags)]
    (v/graphql-query {:venia/queries queries})))
