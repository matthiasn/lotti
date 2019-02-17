(ns meins.jvm.graphql.xforms
  (:require [taoensso.timbre :refer [info error warn debug]]
            [clojure.walk :as walk]
            [com.walmartlabs.lacinia.schema :as schema]
            [clojure.tools.reader.edn :as edn])
  (:import (clojure.lang IPersistentMap)))


(defn simplify [m]
  (walk/postwalk (fn [node]
                   (cond
                     (instance? IPersistentMap node)
                     (into {}
                           (map (fn [[k v]]
                                  (cond

                                    (and v (contains? #{:timestamp
                                                        :ts
                                                        :comment_for
                                                        :linked_saga
                                                        :primary_story
                                                        :adjusted_ts
                                                        :habit_ts
                                                        :last_saved} k))
                                    [k (Long/parseLong v)]

                                    (and v (contains? #{:habit
                                                        :custom_fields
                                                        :custom_field_cfg
                                                        :entry_type
                                                        :priority
                                                        :vclock
                                                        :dashboard_cfg
                                                        :questionnaires} k))
                                    [k (edn/read-string (str v))]

                                    (and v (vector? v)
                                         (contains? #{:tags
                                                      :perm_tags
                                                      :mentions} k))
                                    [k (set v)]

                                    (nil? v) nil

                                    :else [k v]))
                                node))

                     (seq? node) (vec node)
                     :else node))
                 m))

(defn edn-xf [entry]
  (-> entry
      (update-in [:habit] pr-str)
      (update-in [:album] pr-str)
      (update-in [:custom_fields] pr-str)
      (update-in [:custom_field_cfg] pr-str)
      (update-in [:dashboard_cfg] pr-str)
      (update-in [:vclock] pr-str)
      (update-in [:questionnaires] pr-str)))
