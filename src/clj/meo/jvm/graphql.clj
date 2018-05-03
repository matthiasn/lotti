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
            [meo.jvm.store :as st]
            [meo.jvm.graph.stats :as gs]
            [meo.jvm.graph.query :as gq]
            [meo.common.utils.parse :as p]
            [clojure.pprint :as pp])
  (:import (clojure.lang IPersistentMap)))

(defn simplify [m]
  (walk/postwalk (fn [node]
                   (cond
                     (instance? IPersistentMap node) (into {} node)
                     (seq? node) (vec node)
                     :else node))
                 m))

(defn entry-count [context args value] (count (:sorted-entries @st/state)))
(defn hours-logged [context args value] (gs/hours-logged @st/state))
(defn word-count [context args value] (gs/count-words @st/state))
(defn tag-count [context args value] (count (gq/find-all-hashtags @st/state)))
(defn mention-count [context args value] (count (gq/find-all-mentions @st/state)))
(defn completed-count [context args value] (gs/completed-count @st/state))

(defn match-count [context args value]
  (gs/res-count @st/state (p/parse-search (:query args))))

(defn run-query [{:keys [current-state msg-payload]}]
  (let [start (stc/now)
        schema (:schema current-state)
        file (:file msg-payload)
        query-string (if file
                       (slurp (io/resource (str "queries/" file)))
                       (:q msg-payload))
        res (-> (lacinia/execute schema query-string nil nil)
                (simplify))]
    (info "GraphQL query \"" (or file query-string)
          "\" finished in" (- (stc/now) start) "ms")
    (pp/pprint res)
    {:emit-msg [:gql/res (merge msg-payload res)]}))

(defn state-fn [_put-fn]
  (let [schema (-> (edn/read-string (slurp (io/resource "schema.edn")))
                   (util/attach-resolvers
                     {:query/entry-count     entry-count
                      :query/hours-logged    hours-logged
                      :query/word-count      word-count
                      :query/tag-count       tag-count
                      :query/mention-count   mention-count
                      :query/completed-count completed-count
                      :query/match-count     match-count})
                   schema/compile)
        server (-> schema
                   (lp/service-map {:graphiql true :port 7999})
                   http/create-server
                   http/start)]                             ;(http/stop server)
    (info "Started GraphQL component")
    {:state (atom {:server server
                   :schema schema})}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:gql/query run-query}})
