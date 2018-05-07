(ns meo.jvm.graphql
  "GraphQL query component"
  (:require [clojure.java.io :as io]
            [com.walmartlabs.lacinia.util :as util]
            [com.walmartlabs.lacinia.schema :as schema]
            [taoensso.timbre :refer [info error warn]]
            [com.walmartlabs.lacinia :as lacinia]
            [com.walmartlabs.lacinia.pedestal :as lp]
            [io.pedestal.http :as http]
            [ubergraph.core :as uc]
            [matthiasn.systems-toolbox.component :as stc]
            [clojure.walk :as walk]
            [clojure.edn :as edn]
            [meo.jvm.store :as st]
            [meo.jvm.graph.stats :as gs]
            [meo.jvm.graph.query :as gq]
            [meo.common.utils.parse :as p]
            [camel-snake-kebab.core :refer [->kebab-case-keyword ->snake_case]]
            [camel-snake-kebab.extras :refer [transform-keys]]
            [clojure.pprint :as pp]
            [meo.jvm.graph.stats.day :as gsd])
  (:import (clojure.lang IPersistentMap)))

(defn simplify [m]
  (walk/postwalk (fn [node]
                   (cond
                     (instance? IPersistentMap node)
                     (into {} (map (fn [[k v]]
                                     (if (and v
                                              (contains? #{:timestamp
                                                           :comment_for}
                                                         k))
                                       [k (Long/parseLong v)]
                                       [k v]))
                                   node))
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

(defn briefings [context args value]
  (map (fn [[k v]] {:day k :timestamp v})
       (gq/find-all-briefings @st/state)))

(defn logged-time [context args value]
  (let [day (:day args)
        current-state @st/state
        g (:graph current-state)
        stories (gq/find-all-stories current-state)
        sagas (gq/find-all-sagas current-state)
        day-nodes (gq/get-nodes-for-day g {:date-string day})
        day-nodes-attrs (map #(uc/attrs g %) day-nodes)
        day-stats (gsd/day-stats g day-nodes-attrs stories sagas day)]
    (transform-keys ->snake_case day-stats)))

(defn match-count [context args value]
  (gs/res-count @st/state (p/parse-search (:query args))))

(defn started-tasks [context args value]
  (let [q {:tags     #{"#task"}
           :not-tags #{"#done" "#backlog" "#closed"}
           :opts     #{":started"}
           :n        100}
        tasks (:entries-list (gq/get-filtered @st/state q))
        current-state @st/state
        g (:graph current-state)
        stories (gq/find-all-stories @st/state)
        sagas (gq/find-all-sagas @st/state)
        logged-t (fn [comment-ts]
                   (or (when (uc/has-node? g comment-ts)
                         (let [c (uc/attrs g comment-ts)
                               dur-path [:custom-fields "#duration" :duration]]
                           (+ (:completed-time c 0)
                              (* 60 (get-in c dur-path 0)))))
                       0))
        task-total-t (fn [t]
                       (let [logged (apply + (map logged-t (:comments t)))]
                         (assoc-in t [:task :completed-s] logged)))
        add-story (fn [t]
                    (let [story (get-in stories [(:primary-story t)])
                          saga (get-in sagas [(:linked-saga story)])]
                      (merge t
                        {:story (when story
                                  (assoc-in story [:linked-saga] saga))})))
        tasks (mapv task-total-t tasks)
        tasks (mapv add-story tasks)]
    (transform-keys ->snake_case tasks)))

(defn run-query [{:keys [current-state msg-payload]}]
  (let [start (stc/now)
        schema (:schema current-state)
        file (:file msg-payload)
        args (:args msg-payload)
        query-string (if file
                       (slurp (io/resource (str "queries/" file)))
                       (:q msg-payload))
        query-string (apply format query-string args)
        res (lacinia/execute schema query-string nil nil)
        simplified (transform-keys ->kebab-case-keyword (simplify res))]
    (info "GraphQL query" (str "'" (or file query-string) "'")
          "finished in" (- (stc/now) start) "ms")
    {:emit-msg [:gql/res (merge msg-payload simplified)]}))

(defn state-fn [_put-fn]
  (let [port (Integer/parseInt (get (System/getenv) "GQL_PORT" "8766" ))
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
                      :query/logged-time     logged-time
                      :query/started-tasks   started-tasks
                      :query/mentions        mentions
                      :query/stories         stories
                      :query/sagas           sagas
                      :query/briefings       briefings})
                   schema/compile)
        server (-> schema
                   (lp/service-map {:graphiql true
                                    :port     port})
                   http/create-server
                   http/start)]
    (info "Started GraphQL component")
    (info "GraphQL server with GraphiQL data explorer listening on PORT" port)
    {:state       (atom {:server server
                         :schema schema})
     :shutdown-fn #(do (http/stop server)
                       (info "Stopped GraphQL server"))}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :opts        {:in-chan  [:buffer 100]
                 :out-chan [:buffer 100]}
   :handler-map {:gql/query run-query}})
