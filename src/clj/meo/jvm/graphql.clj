(ns meo.jvm.graphql
  "GraphQL query component"
  (:require [clojure.java.io :as io]
            [clojure.edn :as edn]
            [com.climate.claypoole :as cp]
            [com.walmartlabs.lacinia.util :as util]
            [com.walmartlabs.lacinia.schema :as schema]
            [com.walmartlabs.lacinia.pedestal :as lp]
            [io.pedestal.http :as http]
            [meo.jvm.graphql.exec :as exec]
            [meo.jvm.graphql.habits :as gh]
            [meo.jvm.graphql.tasks :as gt]
            [meo.jvm.graphql.opts :as opts]
            [meo.jvm.graphql.misc-stats :as gms]
            [meo.jvm.graphql.tab-search :as gts]
            [meo.jvm.graphql.briefings-logged :as gbl]
            [meo.jvm.graph.geo :as geo]
            [taoensso.timbre :refer [info error warn debug]]
            [meo.jvm.graphql.custom-fields :as gcf]))

(defn search-remove [{:keys [current-state msg-payload]}]
  (let [tab-group (:tab-group msg-payload)
        queries (-> (into {} (:queries current-state))
                    (dissoc tab-group))
        new-state (-> current-state
                      (assoc-in [:prev tab-group] {})
                      (assoc-in [:queries] queries))]
    (info "removing query" msg-payload (keys queries))
    {:new-state new-state}))

(defn run-registered [{:keys [current-state msg-meta] :as m}]
  (let [queries (sort-by #(:prio (second %)) (:queries current-state))]
    (info "Running registered GraphQL queries" (keys queries))
    (doseq [[id _q] queries]
      (exec/run-query (merge m {:msg-payload {:id id}
                                :msg-meta    msg-meta}))))
  {})

(defn start-stop [{:keys [current-state msg-payload]}]
  (let [server (:server current-state)]
    (if (= :start (:cmd msg-payload))
      (let [port (:port current-state)]
        (http/start server)
        (info "GraphQL server with GraphiQL data explorer listening on PORT" port))
      (do (http/stop server)
          (info "Stopped GraphQL server")))
    {}))

(defn state-fn [state put-fn]
  (let [port (Integer/parseInt (get (System/getenv) "GQL_PORT" "8766"))
        attach-state (fn [m]
                       (into {} (map (fn [[k f]]
                                       [k (partial (exec/async-wrapper k f) state)])
                                     m)))
        schema (-> (edn/read-string (slurp (io/resource "schema.edn")))
                   (util/attach-resolvers
                     (attach-state
                       {:query/entry-count        opts/entry-count
                        :query/hours-logged       opts/hours-logged
                        :query/word-count         opts/word-count
                        :query/tag-count          opts/tag-count
                        :query/mention-count      opts/mention-count
                        :query/completed-count    opts/completed-count
                        :query/match-count        gms/match-count
                        :query/active-threads     opts/thread-count
                        :query/pid                opts/pid
                        :query/tab-search         (gts/tab-search put-fn)
                        :query/hashtags           opts/hashtags
                        :query/pvt-hashtags       opts/pvt-hashtags
                        :query/logged-time        gbl/logged-time
                        :query/day-stats          gbl/day-stats
                        :query/habits-success     gh/habits-success
                        :query/started-tasks      gt/started-tasks
                        :query/open-tasks         gt/open-tasks
                        :query/waiting-habits     gh/waiting-habits
                        :query/mentions           opts/mentions
                        :query/stories            opts/stories
                        :query/sagas              opts/sagas
                        :query/geo-photos         geo/photos-within-bounds
                        :query/custom-field-stats gcf/custom-field-stats
                        :query/bp-field-stats     gms/bp-field-stats
                        :query/git-stats          gms/git-stats
                        :query/briefings          opts/briefings
                        :query/questionnaires     gms/questionnaires
                        :query/award-points       gms/award-points
                        :query/briefing           gbl/briefing}))
                   schema/compile)
        server (-> schema
                   (lp/service-map {:graphiql true
                                    :port     port})
                   (assoc-in [::http/host] "localhost")
                   http/create-server)]
    (swap! state assoc-in [:server] server)
    (swap! state assoc-in [:port] port)
    (swap! state assoc-in [:schema] schema)
    (info "Started GraphQL component")
    {:state       state
     :shutdown-fn #(do (http/stop server)
                       (info "Stopped GraphQL server"))}))
