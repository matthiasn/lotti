(ns meins.electron.renderer.ui.geo.queries
  (:require [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug error info]]
            [venia.core :as v]))

(defn queries [local]
  (let [{:keys [from to]} @local
        q1 [:locations_by_days
            {:from from
             :to   to}
            [:type
             [:geometry [:type
                         :coordinates]]
             [:properties [:activity
                           :data
                           [:entry [:md
                                    :timestamp
                                    :img_file
                                    :img_rel_path]]
                           :accuracy
                           :timestamp
                           :entry_type]]]]
        q2 [:lines_by_days
            {:from     from
             :to       to
             :accuracy 250}
            [:type
             [:geometry [:type
                         :coordinates]]
             [:properties [:activity]]]]
        gql (v/graphql-query {:venia/queries [{:query/data q1}
                                              {:query/data q2}]})
        q {:id       :locations-map
           :q        gql
           :res-hash nil
           :prio     15}]
    (emit [:gql/query q])))
