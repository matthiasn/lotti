(ns meins.electron.renderer.graphql
  (:require #?(:clj  [taoensso.timbre :refer [debug info warn]]
               :cljs [taoensso.timbre :refer [debug info warn]])
            [clojure.string :as s]
            [venia.core :as v]))

(defn graphql-query [days offset tags]
  (let [qfn (fn [t]
              {:query/data  [:custom_field_stats {:days   days
                                                  :offset offset
                                                  :tag    t}
                             [:date_string
                              [:fields [:field :value
                                        [:values [:ts :v]]]]]]
               :query/alias (keyword (s/replace (subs (str t) 1) "-" "_"))})
        queries (mapv qfn tags)
        git-query {:query/data [:git_stats {:days   days
                                            :offset offset}
                                [:date_string :commits]]}
        queries (conj queries git-query)]
    (when (seq queries)
      (v/graphql-query {:venia/queries queries}))))

(defn graphql-query-by-day [day tag alias]
  (let [q {:query/data  [:custom_field_stats_by_day {:day day
                                                     :tag tag}
                         [:date_string
                          [:fields [:field :value
                                    [:values [:ts :v]]]]]]
           :query/alias alias}]
    (v/graphql-query {:venia/queries [q]})))

(defn graphql-query-by-days [day-strings tags alias]
  (let [q {:query/data  [:custom_fields_by_days
                         {:day_strings day-strings
                          :tags        tags}
                         [:date_string
                          :tag
                          [:fields [:field :value
                                    [:values [:ts :v]]]]]]
           :query/alias alias}]
    (v/graphql-query {:venia/queries [q]})))

(defn habits-query-by-days [day-strings pvt]
  (let [q {:query/data [:habits_success_by_day
                        {:day_strings day-strings
                         :pvt         pvt}
                        [:day
                         :habit_ts
                         :success]]}]
    (v/graphql-query {:venia/queries [q]})))

(defn dashboard-questionnaires-by-days [day-strings item]
  (let [qfn (fn [{:keys [tag score_k] :as cfg}]
              (if tag
                (let [kn (name score_k)
                      alias (keyword
                              (str (s/replace (subs (str tag) 1) "-" "_") "_" kn))]
                  {:query/data  [:questionnaires_by_days
                                 {:day_strings day-strings
                                  :tag         tag
                                  :k           kn}
                                 [:timestamp
                                  :adjusted_ts
                                  :date_string
                                  :score
                                  :agg
                                  :tag]]
                   :query/alias alias})
                (warn "no tag:" cfg)))
        queries (filter identity [(qfn item)])]
    (when (seq queries)
      (v/graphql-query {:venia/queries queries}))))

(defn tabs-query [queries incremental pvt]
  (let [fields [:timestamp
                :adjusted_ts
                :text
                :md
                :latitude
                :longitude
                :starred
                :linked_cnt
                :arrival_timestamp
                :departure_timestamp
                :img_file
                :img_rel_path
                :last_saved
                :audio_file
                :tags
                :perm_tags
                :mentions
                :habit
                :hidden
                :primary_story
                :story_name
                :saga_name
                :story_cfg
                [:story_cfg [:active :pvt :font_color :badge_color]]
                [:problem_cfg [:active :pvt :name]]
                [:saga_cfg [:active :pvt]]
                :linked_saga
                :stars
                :questionnaires
                :custom_fields
                :custom_field_cfg
                :dashboard_cfg
                [:album_cfg [:title :pvt :active]]
                :entry_type
                [:vclock [:node :clock]]
                [:task [:completion_ts
                        :done
                        :closed
                        :closed_ts
                        :estimate_m
                        :on_hold
                        :points
                        :priority]]
                [:git_commit [:repo_name
                              :refs
                              :commit
                              :subject
                              :abbreviated_commit]]
                [:comments [:timestamp
                            :md
                            :tags
                            :mentions
                            :latitude
                            :longitude
                            :img_file
                            :img_rel_path
                            :starred
                            :adjusted_ts
                            :comment_for
                            :entry_type
                            :completed_time
                            :custom_fields
                            :questionnaires]]
                [:linked [:timestamp
                          :adjusted_ts
                          :md
                          :tags
                          :mentions
                          :stars
                          :latitude
                          :longitude
                          :img_file
                          :img_rel_path]]
                [:reward [:claimed
                          :claimed_ts
                          :points]]
                [:spotify [:name
                           :uri
                           :image
                           [:artists [:name]]]]
                [:story [:timestamp
                         :story_name
                         [:saga [:saga_name]]]]]
        f (fn [[k {:keys [n search-text story flagged starred from to]}]]
            {:query/data  [:tab_search {:query       search-text
                                        :from        from
                                        :to          to
                                        :pvt         pvt
                                        :incremental incremental
                                        :starred     starred
                                        :flagged     flagged
                                        :story       story
                                        :prio        1
                                        :tab         (name k)
                                        :n           n} fields]
             :query/alias k})
        queries (mapv f queries)]
    (when (seq queries)
      (v/graphql-query {:venia/queries queries}))))

(defn gen-query [q]
  (let [q [{:query/data q}]]
    (when (seq q)
      (v/graphql-query {:venia/queries q}))))

(defn usage-query []
  (let [q {:query/data [:usage_by_day
                        {:geohash_precision 2}
                        [:id_hash
                         :entries
                         :hours_logged
                         :tasks
                         :tasks_done
                         :habits
                         :hashtags
                         :words
                         :stories
                         :sagas
                         :os
                         :dur
                         :geohashes]]}]
    [:gql/query {:q        (v/graphql-query {:venia/queries [q]})
                 :res-hash nil
                 :once     true
                 :id       :usage-by-day
                 :prio     15}]))