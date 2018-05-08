(ns meo.jvm.graphql
  "GraphQL query component"
  (:require [clojure.java.io :as io]
            [com.walmartlabs.lacinia.util :as util]
            [com.walmartlabs.lacinia.schema :as schema]
            [taoensso.timbre :refer [info error warn debug]]
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
            [meo.jvm.graph.stats.day :as gsd]
            [meo.jvm.datetime :as dt]
            [meo.jvm.graph.stats.custom-fields :as cf]
            [meo.jvm.graph.stats.git :as g]
            [meo.jvm.graph.stats.questionnaires :as q])
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
(defn word-count [context args value] (gs/count-words2 @st/state))
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

(defn get-entry [g ts]
  (when (and ts (uc/has-node? g ts))
    (uc/attrs g ts)))

(defn entry-w-story [g entry]
  (let [story (get-entry g (:primary-story entry))
        saga (get-entry g (:linked-saga story))]
    (merge entry
           {:story (when story
                     (assoc-in story [:linked-saga] saga))})))

(defn snake-xf [xs] (transform-keys ->snake_case xs))

(def d (* 24 60 60 1000))

(defn briefing [context args value]
  (let [g (:graph @st/state)
        d (:day args)
        ts (first (gq/get-briefing-for-day g {:briefing d}))
        briefing (get-entry g ts)
        linked (gq/get-linked-for-ts g (:timestamp briefing))
        linked (mapv #(entry-w-story g (get-entry g %)) linked)]
    (when briefing
      (snake-xf (merge briefing {:day    d
                                 :linked linked})))))

(defn logged-time [context args value]
  (let [day (:day args)
        current-state @st/state
        g (:graph current-state)
        stories (gq/find-all-stories current-state)
        sagas (gq/find-all-sagas current-state)
        day-nodes (gq/get-nodes-for-day g {:date-string day})
        day-nodes-attrs (map #(get-entry g %) day-nodes)
        day-stats (gsd/day-stats g day-nodes-attrs stories sagas day)]
    (snake-xf day-stats)))

(defn match-count [context args value]
  (gs/res-count @st/state (p/parse-search (:query args))))

(defn custom-field-stats [context args value]
  (let [{:keys [days tag]} args
        days (reverse (range days))
        now (stc/now)
        custom-fields-mapper (cf/custom-fields-mapper @st/state tag)
        day-strings (mapv #(dt/ts-to-ymd (- now (* % d))) days)
        stats (mapv custom-fields-mapper day-strings)]
    (snake-xf stats)))

(defn git-stats [context args value]
  (info "git-stats" args)
  (let [{:keys [days]} args
        days (reverse (range days))
        now (stc/now)
        git-mapper (g/git-mapper @st/state)
        day-strings (mapv #(dt/ts-to-ymd (- now (* % d))) days)
        stats (mapv git-mapper day-strings)]
    (debug stats)
    (snake-xf stats)))

(defn questionnaires [context args value]
  (info "git-stats" args)
  (let [{:keys [days tag k]} args
        newer-than (- (stc/now) (* d (or days 90)))
        stats (q/questionnaires-by-tag @st/state tag (keyword k))
        stats (filter #(:score %) stats)
        stats (vec (filter #(> (:timestamp %) newer-than) stats))]
    (debug stats)
    (snake-xf stats)))

(defn started-tasks [context args value]
  (let [q {:tags     #{"#task"}
           :not-tags #{"#done" "#backlog" "#closed"}
           :opts     #{":started"}
           :n        100}
        current-state @st/state
        tasks (:entries-list (gq/get-filtered current-state q))
        g (:graph current-state)
        logged-t (fn [comment-ts]
                   (or
                     (when-let [c (get-entry g comment-ts)]
                       (let [path [:custom-fields "#duration" :duration]]
                         (+ (:completed-time c 0)
                            (* 60 (get-in c path 0)))))
                     0))
        task-total-t (fn [t]
                       (let [logged (apply + (map logged-t (:comments t)))]
                         (assoc-in t [:task :completed-s] logged)))
        tasks (mapv task-total-t tasks)
        tasks (mapv #(entry-w-story g %) tasks)]
    (snake-xf tasks)))

(defn waiting-habits [context args value]
  (let [q {:tags #{"#habit"}
           :opts #{":waiting"}
           :n    100}
        current-state @st/state
        g (:graph current-state)
        habits (filter identity (:entries-list (gq/get-filtered current-state q)))
        habits (mapv #(entry-w-story g %) habits)
        habits (mapv #(update-in % [:story] snake-xf) habits)]
    habits))

(defn run-query [{:keys [current-state msg-payload]}]
  (let [start (stc/now)
        schema (:schema current-state)
        {:keys [file args q id]} msg-payload
        template (if file (slurp (io/resource (str "queries/" file))) q)
        query-string (apply format template args)
        res (lacinia/execute schema query-string nil nil)
        simplified (transform-keys ->kebab-case-keyword (simplify res))]
    (info "GraphQL query" id "finished in" (- (stc/now) start) "ms"
          (str "'" (or file query-string) "'"))
    {:emit-msg [:gql/res (merge msg-payload simplified)]}))

(defn state-fn [_put-fn]
  (let [port (Integer/parseInt (get (System/getenv) "GQL_PORT" "8766"))
        schema (-> (edn/read-string (slurp (io/resource "schema.edn")))
                   (util/attach-resolvers
                     {:query/entry-count        entry-count
                      :query/hours-logged       hours-logged
                      :query/word-count         word-count
                      :query/tag-count          tag-count
                      :query/mention-count      mention-count
                      :query/completed-count    completed-count
                      :query/match-count        match-count
                      :query/hashtags           hashtags
                      :query/pvt-hashtags       pvt-hashtags
                      :query/logged-time        logged-time
                      :query/started-tasks      started-tasks
                      :query/waiting-habits     waiting-habits
                      :query/mentions           mentions
                      :query/stories            stories
                      :query/sagas              sagas
                      :query/custom-field-stats custom-field-stats
                      :query/git-stats          git-stats
                      :query/briefings          briefings
                      :query/questionnaires     questionnaires
                      :query/briefing           briefing})
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
