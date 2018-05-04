(ns meo.jvm.graphql
  "GraphQL query component"
  (:require [clojure.java.io :as io]
            [com.walmartlabs.lacinia.util :as util]
            [com.walmartlabs.lacinia.schema :as schema]
            [taoensso.timbre :refer [info error warn]]
            [com.walmartlabs.lacinia :as lacinia]
            [com.walmartlabs.lacinia.pedestal :as lp]
            [io.pedestal.http :as http]
            [matthiasn.systems-toolbox.component :as stc]
            [clojure.walk :as walk]
            [clojure.edn :as edn]
            [meo.jvm.upload :as u]
            [meo.jvm.store :as st]
            [meo.jvm.graph.stats :as gs]
            [meo.jvm.graph.query :as gq]
            [meo.common.utils.parse :as p]
            [camel-snake-kebab.core :refer [->kebab-case-keyword]]
            [camel-snake-kebab.extras :refer [transform-keys]]
            [clojure.pprint :as pp])
  (:import (clojure.lang IPersistentMap)))

(defn simplify [m]
  (walk/postwalk (fn [node]
                   (cond
                     (instance? IPersistentMap node)
                     (into {} (map (fn [[k v]] (if (= k :timestamp)
                                                 [k (Long/parseLong v)]
                                                 [k v])) node))
                     (seq? node) (vec node)
                     :else node))
                 m))

(defn entry-count [context args value] (count (:sorted-entries @st/state)))
(defn hours-logged [context args value] (gs/hours-logged @st/state))
(defn word-count [context args value] (gs/count-words @st/state))
(defn tag-count [context args value] (count (gq/find-all-hashtags @st/state)))
(defn mention-count [context args value] (count (gq/find-all-mentions @st/state)))
(defn completed-count [context args value] (gs/completed-count @st/state))

(defn hashtags [context args value] (gq/find-all-hashtags @st/state))
(defn pvt-hashtags [context args value] (gq/find-all-pvt-hashtags @st/state))
(defn mentions [context args value] (gq/find-all-mentions @st/state))

(defn stories [context args value] (gq/find-all-stories2 @st/state))
(defn sagas [context args value] (gq/find-all-sagas2 @st/state))
(defn briefings [context args value] (map
                                       (fn [[k v]] {:day k :timestamp v})
                                       (gq/find-all-briefings @st/state)))

(defn match-count [context args value]
  (gs/res-count @st/state (p/parse-search (:query args))))

(defn run-query [{:keys [current-state msg-payload]}]
  (let [start (stc/now)
        schema (:schema current-state)
        file (:file msg-payload)
        query-string (if file
                       (slurp (io/resource (str "queries/" file)))
                       (:q msg-payload))
        res (lacinia/execute schema query-string nil nil)
        simplified (transform-keys ->kebab-case-keyword (simplify res))]
    (info "GraphQL query \"" (or file query-string)
          "\" finished in" (- (stc/now) start) "ms")
    {:emit-msg [:gql/res (merge msg-payload simplified)]}))

(defn state-fn [_put-fn]
  (let [port (u/get-free-port)
        port 8766
        schema (-> (edn/read-string (slurp (io/resource "schema.edn")))
                   (util/attach-resolvers
                     {:query/entry-count     entry-count
                      :query/hours-logged    hours-logged
                      :query/word-count      word-count
                      :query/tag-count       tag-count
                      :query/mention-count   mention-count
                      :query/completed-count completed-count
                      :query/match-count     match-count
                      :query/hashtags        hashtags
                      :query/pvt-hashtags    pvt-hashtags
                      :query/mentions        mentions
                      :query/stories         stories
                      :query/sagas           sagas
                      :query/briefings       briefings})
                   schema/compile)
        server (-> schema
                   (lp/service-map {:graphiql true
                                    :port     port})
                   http/create-server
                   http/start)]                             ;(http/stop server)
    (info "Started GraphQL component, listening on port" port)
    {:state (atom {:server server
                   :schema schema})}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :opts        {:in-chan  [:buffer 100]
                 :out-chan [:buffer 100]}
   :handler-map {:gql/query run-query}})
