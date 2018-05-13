(ns meo.jvm.graphql.xforms
  (:require [taoensso.timbre :refer [info error warn debug]]
            [camel-snake-kebab.core :refer [->snake_case ->kebab-case-keyword]]
            [camel-snake-kebab.extras :refer [transform-keys]]
            [clojure.walk :as walk]
            [com.walmartlabs.lacinia.schema :as schema]
            [clojure.tools.reader.edn :as edn])
  (:import (clojure.lang IPersistentMap)))

(defn snake-xf [xs] (transform-keys ->snake_case xs))

(defn kebab-or-number [k]
  (cond
    (number? k) k
    (and (string? k) (= "#" (subs k 0 1))) k
    :else (->kebab-case-keyword k)))

(defn simplify [m]
  (transform-keys
    kebab-or-number
    (walk/postwalk (fn [node]
                     (cond
                       (instance? IPersistentMap node)
                       (into {}
                             (map (fn [[k v]]
                                    (cond

                                      (and v (contains? #{:timestamp
                                                          :comment_for
                                                          :last_saved}
                                                        k))
                                      [k (Long/parseLong v)]

                                      (and v (contains? #{:habit
                                                          :custom_fields
                                                          :questionnaires}
                                                        k))
                                      [k (edn/read-string v)]

                                      :else [k v]))
                                  node))

                       (seq? node) (vec node)
                       :else node))
                   m)))

(defn vclock-xf [entry]
  (update-in entry [:vclock] #(mapv (fn [[k v]] {:node k :clock v}) %)))

(defn edn-xf [entry]
  (-> entry
      (update-in [:habit] pr-str)
      (update-in [:custom-fields] pr-str)
      (update-in [:questionnaires] pr-str)))
