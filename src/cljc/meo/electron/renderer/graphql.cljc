(ns meo.electron.renderer.graphql
  (:require [venia.core :as v]
    #?(:clj
            [taoensso.timbre :refer [info debug warn]]
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

(defn tabs-query [queries pvt]
  (let [n 20
        fields [:timestamp
                :text
                :md
                :latitude
                :longitude
                :starred
                :linked_cnt
                :arrival_timestamp
                :departure_timestamp
                :img_file
                :last_saved
                :audio_file
                :tags
                :perm_tags
                :mentions
                :habit
                :story_name
                :saga_name
                :linked_saga
                :stars
                :for_day
                :questionnaires
                :custom_fields
                :entry_type
                [:vclock [:node :clock]]
                [:task [:completed_s
                        :completion_ts
                        :done
                        :rejected
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
                            :starred
                            :for_day
                            :comment_for
                            :entry_type
                            :completed_time
                            :custom_fields
                            :questionnaires]]
                [:linked [:timestamp
                          :md
                          :tags
                          :mentions
                          :stars
                          :latitude
                          :longitude
                          :img_file]]
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
        f (fn [[k {:keys [n search-text story]}]]
            {:query/data  [:tab_search {:query search-text
                                        :pvt   pvt
                                        :story story
                                        :prio  1
                                        :n     n} fields]
             :query/alias k})
        queries (mapv f queries)]
    (when (seq queries)
      (v/graphql-query {:venia/queries queries}))))

(defn gen-query [q]
  (let [q [{:query/data q}]]
    (when (seq q)
      (v/graphql-query {:venia/queries q}))))
