(ns meo.electron.renderer.graphql
  (:require  [venia.core :as v]
    #?(:clj  [taoensso.timbre :refer [info debug warn]]
       :cljs [taoensso.timbre :refer-macros [info debug warn]])
             [clojure.string :as s]))

(defn graphql-query [days tags]
  (let [qfn (fn [t]
              {:query/data  [:custom_field_stats {:days days :tag t}
                             [:date_string [:fields [:field :value]]]]
               :query/alias (keyword (s/replace (subs t 1) "-" "_"))})
        queries (mapv qfn tags)
        git-query {:query/data [:git_stats {:days days}
                                [:date_string :commits]]}
        award-query {:query/data [:award_points {:days (inc days)}
                                  [:total :claimed :total_skipped
                                   [:by_day [:date_string :habit :task]]
                                   [:by_day_skipped [:date_string :habit]]]]}
        queries (conj queries git-query award-query)]
    (when (seq queries)
      (v/graphql-query {:venia/queries queries}))))

(defn dashboard-questionnaires [days items]
  (let [qfn (fn [{:keys [tag score-k] :as cfg}]
              (if tag
                (let [kn (name score-k)
                      alias (keyword
                              (str (s/replace (subs tag 1) "-" "_") "_" kn))]
                  {:query/data  [:questionnaires {:days days
                                                  :tag  tag
                                                  :k    kn}
                                 [:timestamp :score]]
                   :query/alias alias})
                (warn "no tag:" cfg)))
        queries (filter identity (mapv qfn items))]
    (when (seq queries)
      (v/graphql-query {:venia/queries queries}))))

(defn tabs-query [queries]
  (let [qfn (fn [[k q]]
              {:query/data  [:tab_search {:query q}
                             [:timestamp :text]]
               :query/alias k})
        queries (mapv qfn queries)]
    (when (seq queries)
      (v/graphql-query {:venia/queries queries}))))
