(ns meo.electron.renderer.graphql
  (:require [venia.core :as v]
            [taoensso.timbre :refer-macros [info debug]]
            [clojure.string :as s]))

(defn graphql-query [days tags]
  (let [qfn (fn [t]
              {:query/data  [:custom_field_stats {:days days :tag t}
                             [:date_string [:fields [:field :value]]]]
               :query/alias (keyword (s/replace (subs t 1) "-" "_"))})
        queries (mapv qfn tags)
        git-query {:query/data  [:git_stats {:days (+ 2 days)}
                                 [:date_string :commits]]
                   :query/alias :git_commits}
        queries (conj queries git-query)]
    (v/graphql-query {:venia/queries queries})))
