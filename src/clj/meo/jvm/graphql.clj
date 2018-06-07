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
            [clojure.edn :as edn]
            [com.climate.claypoole :as cp]
            [com.walmartlabs.lacinia.util :as lu]
            [meo.jvm.graphql.xforms :as xf]
            [meo.jvm.graph.stats :as gs]
            [meo.jvm.graph.query :as gq]
            [meo.common.utils.parse :as p]
            [camel-snake-kebab.core :refer [->kebab-case-keyword ->snake_case]]
            [camel-snake-kebab.extras :refer [transform-keys]]
            [meo.jvm.graph.stats.day :as gsd]
            [meo.jvm.datetime :as dt]
            [meo.jvm.graph.stats.custom-fields :as cf]
            [meo.jvm.graph.stats.git :as g]
            [meo.jvm.graph.stats.questionnaires :as q]
            [meo.jvm.graph.stats.awards :as aw]
            [meo.jvm.graph.geo :as geo]
            [com.walmartlabs.lacinia.parser :as parser]
            [com.walmartlabs.lacinia.resolve :as resolve])
  (:import [clojure.lang ExceptionInfo]))

(defn entry-count [state context args value] (count (:sorted-entries @state)))
(defn hours-logged [state context args value] (gs/hours-logged @state))
(defn word-count [state context args value] (gs/count-words @state))
(defn tag-count [state context args value] (count (gq/find-all-hashtags @state)))
(defn mention-count [state context args value] (count (gq/find-all-mentions @state)))
(defn completed-count [state context args value] (gs/completed-count @state))

(defn hashtags [state context args value] (-> @state :options :hashtags))
(defn pvt-hashtags [state context args value] (-> @state :options :pvt-hashtags))
(defn mentions [state context args value] (-> @state :options :mentions))
(defn stories [state context args value] (-> @state :options :stories))
(defn sagas [state context args value] (-> @state :options :sagas))

(defn thread-count [state context args value] (Thread/activeCount))

(defn briefings [state context args value]
  (map (fn [[k v]] {:day k :timestamp v})
       (gq/find-all-briefings @state)))

(defn get-entry [g ts]
  (when (and ts (uc/has-node? g ts))
    (xf/vclock-xf (uc/attrs g ts))))

(defn entry-w-story [g entry]
  (let [story (get-entry g (:primary_story entry))
        saga (get-entry g (:linked_saga story))]
    (merge entry
           {:story (when story
                     (assoc-in story [:saga] saga))})))

(def d (* 24 60 60 1000))

(defn entry-w-comments [g entry]
  (let [comments (mapv #(get-entry g %) (:comments entry))]
    (assoc-in entry [:comments] comments)))

(defn linked-for [g entry]
  (let [ts (:timestamp entry)]
    (assoc-in entry [:linked] (->> (gq/get-linked-for-ts g ts)
                                   (map #(entry-w-story g (get-entry g %)))
                                   (filter :timestamp)
                                   (vec)))))

(defn briefing [state context args value]
  (let [g (:graph @state)
        d (:day args)
        ts (first (gq/get-briefing-for-day g {:briefing d}))]
    (when-let [briefing (get-entry g ts)]
      (let [briefing (linked-for g briefing)
            comments (:comments (gq/get-comments briefing g ts))
            comments (mapv #(update-in (get-entry g %) [:questionnaires :pomo1] vec)
                           comments)
            briefing (merge briefing {:comments comments
                                      :day      d})]
        briefing))))

(defn logged-time [state context args value]
  (let [day (:day args)
        current-state @state
        g (:graph current-state)
        stories (gq/find-all-stories current-state)
        sagas (gq/find-all-sagas current-state)
        day-nodes (gq/get-nodes-for-day g {:date_string day})
        day-nodes-attrs (map #(get-entry g %) day-nodes)
        day-stats (gsd/day-stats g day-nodes-attrs stories sagas day)]
    day-stats))

(defn day-stats [state context args value]
  (let [current-state @state
        g (:graph current-state)
        stories (gq/find-all-stories current-state)
        sagas (gq/find-all-sagas current-state)
        days (reverse (range (:days args 90)))
        now (stc/now)
        day-strings (mapv #(dt/ts-to-ymd (- now (* % d))) days)
        f (fn [day]
            (let [day-nodes (gq/get-nodes-for-day g {:date_string day})
                  day-nodes-attrs (map #(get-entry g %) day-nodes)]
              (gsd/day-stats g day-nodes-attrs stories sagas day)))
        stats (mapv f day-strings)]
    stats))

(defn match-count [state context args value]
  (gs/res-count @state (p/parse-search (:query args))))

(defn entries-w-logged [g entries]
  (let [logged-t (fn [comment-ts]
                   (or
                     (when-let [c (get-entry g comment-ts)]
                       (let [path [:custom_fields "#duration" :duration]]
                         (+ (or (:completed_time c) 0)
                            (* 60 (or (get-in c path) 0)))))
                     0))
        task-total-t (fn [t]
                       (let [logged (apply + (map logged-t (:comments t)))]
                         (assoc-in t [:task :completed_s] logged)))]
    (mapv task-total-t entries)))

(defn tab-search [state context args value]
  (let [{:keys [query n pvt]} args
        current-state @state
        g (:graph current-state)
        q (update-in (p/parse-search query) [:n] #(or n %))
        q (assoc-in q [:pvt] pvt)
        res (->> (gq/get-filtered2 current-state q)
                 (filter #(not (:comment_for %)))
                 (mapv (partial entry-w-story g))
                 (entries-w-logged g)
                 (mapv xf/vclock-xf)
                 (mapv xf/edn-xf)
                 (mapv (partial entry-w-comments g))
                 (mapv (partial linked-for g))
                 (mapv #(assoc % :linked_cnt (count (:linked_entries_list %)))))]
    (debug res)
    res))

(defn custom-field-stats [state context args value]
  (let [{:keys [days tag]} args
        days (reverse (range days))
        now (stc/now)
        custom-fields-mapper (cf/custom-fields-mapper @state tag)
        day-strings (mapv #(dt/ts-to-ymd (- now (* % d))) days)
        stats (mapv custom-fields-mapper day-strings)]
    stats))

(defn git-stats [state context args value]
  (let [{:keys [days]} args
        days (reverse (range days))
        now (stc/now)
        git-mapper (g/git-mapper @state)
        day-strings (mapv #(dt/ts-to-ymd (- now (* % d))) days)
        stats (mapv git-mapper day-strings)]
    (debug stats)
    stats))

(defn questionnaires [state context args value]
  (let [{:keys [days tag k]} args
        newer-than (- (stc/now) (* d (or days 90)))
        stats (q/questionnaires-by-tag @state tag (keyword k))
        stats (filter #(:score %) stats)
        stats (vec (filter #(> (:timestamp %) newer-than) stats))]
    (debug stats)
    stats))

(defn award-points [state context args value]
  (let [{:keys [days]} args
        newer-than (dt/ts-to-ymd (- (stc/now) (* d (or days 90))))
        stats (aw/award-points @state)
        sort-filter (fn [k]
                      (sort-by first (filter #(pos? (compare (first %) newer-than))
                                             (k stats))))
        xf (fn [[k v]] (merge v {:date_string k}))
        sorted (assoc-in stats [:by-day] (mapv xf (sort-filter :by-day)))]
    (assoc-in sorted [:by-day-skipped] (mapv xf (sort-filter :by-day-skipped)))))

(defn started-tasks [state context args value]
  (let [q {:tags     #{"#task"}
           :not-tags #{"#done" "#backlog" "#closed"}
           :opts     #{":started"}
           :n        100
           :pvt      (:pvt args)}
        current-state @state
        g (:graph current-state)
        tasks (->> (gq/get-filtered2 current-state q)
                   (entries-w-logged g)
                   (mapv #(entry-w-story g %))
                   (mapv (partial entry-w-comments g)))]
    tasks))

(defn waiting-habits [state context args value]
  (let [q {:tags #{"#habit"}
           :opts #{":waiting"}
           :n    100
           :pvt  (:pvt args)}
        current-state @state
        g (:graph current-state)
        habits (filter identity (gq/get-filtered2 current-state q))
        habits (mapv #(entry-w-story g %) habits)]
    habits))

(defn ^:private as-errors
  [exception]
  {:errors [(lu/as-error-map exception)]})

(defn execute-async [schema query variables context options on-deliver]
  {:pre [(string? query)]}
  (let [{:keys [operation-name]} options
        [parsed error-result] (try
                                [(parser/parse-query schema query operation-name)]
                                (catch ExceptionInfo e
                                  [nil (as-errors e)]))]
    (if (some? error-result)
      (error "GraphQL error" error-result)
      (let [res (lacinia/execute-parsed-query-async parsed variables context)]
        (resolve/on-deliver! res on-deliver)))))

(def executor-thread-pool (cp/threadpool 5))
(def thread-pool (cp/priority-threadpool 2))
(def prio-thread-pool (cp/priority-threadpool 5))
(alter-var-root #'resolve/*callback-executor* (constantly executor-thread-pool))

(defn async-wrapper [f]
  (fn [state context args value]
    (let [result-promise (resolve/resolve-promise)
          p (:prio args 100)
          tp (if (< p 100)
               prio-thread-pool
               thread-pool)]
      (cp/future (cp/with-priority tp p)
                 (try
                   (let [res (f state context args value)]
                     (resolve/deliver! result-promise res))
                   (catch Throwable t
                     (resolve/deliver! result-promise nil
                                       {:message (str "Exception: " (.getMessage t))}))))
      result-promise)))

(defn run-query [{:keys [cmp-state current-state msg-payload put-fn]}]
  (let [start (stc/now)
        schema (:schema current-state)
        qid (:id msg-payload)
        merged (merge (get-in current-state [:queries qid]) msg-payload)
        {:keys [file args q id res-hash]} merged
        template (if file (slurp (io/resource (str "queries/" file))) q)
        query-string (apply format template args)
        on-deliver
        (fn [res]
          (info "GraphQL on-deliver" qid (- (stc/now) start) "ms")
          (let [new-hash (hash res)
                new-data (not= new-hash res-hash)
                res (merge merged
                           (xf/simplify res)
                           {:res-hash new-hash
                            :ts       (stc/now)
                            :prio     (:prio merged 100)})]
            (swap! cmp-state assoc-in [:queries id] (dissoc res :data))
            (info "GraphQL query" id "finished in" (- (stc/now) start) "ms -"
                  (if new-data "new data" "same hash, omitting response")
                  (str "- '" (or file query-string) "'"))
            (when new-data (put-fn (with-meta [:gql/res res]
                                              {:sente-uid :broadcast})))))]
    (execute-async schema query-string nil nil {} on-deliver))
  {})

(defn run-registered [{:keys [current-state msg-meta] :as m}]
  (info "Running registered GraphQL queries")
  (doseq [[id _q] (sort-by #(:prio (second %)) (:queries current-state))]
    (run-query (merge m {:msg-payload {:id id}
                         :msg-meta    msg-meta})))
  {})

(defn gen-options [{:keys [current-state cmp-state]}]
  (cp/future
    thread-pool
    (let [start (stc/now)
          opts {:hashtags     (gq/find-all-hashtags current-state)
                :pvt-hashtags (gq/find-all-pvt-hashtags current-state)
                :mentions     (gq/find-all-mentions current-state)
                :stories      (gq/find-all-stories2 current-state)
                :sagas        (gq/find-all-sagas2 current-state)}]
      (swap! cmp-state assoc-in [:options] opts)
      (info "gen-options finished in" (- (stc/now) start) "ms")))
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

(defn state-fn [state _put-fn]
  (let [port (Integer/parseInt (get (System/getenv) "GQL_PORT" "8766"))
        attach-state (fn [m]
                       (into {} (map (fn [[k f]]
                                       [k (partial (async-wrapper f) state)])
                                     m)))
        schema (-> (edn/read-string (slurp (io/resource "schema.edn")))
                   (util/attach-resolvers
                     (attach-state
                       {:query/entry-count        entry-count
                        :query/hours-logged       hours-logged
                        :query/word-count         word-count
                        :query/tag-count          tag-count
                        :query/mention-count      mention-count
                        :query/completed-count    completed-count
                        :query/match-count        match-count
                        :query/active-threads     thread-count
                        :query/tab-search         tab-search
                        :query/hashtags           hashtags
                        :query/pvt-hashtags       pvt-hashtags
                        :query/logged-time        logged-time
                        :query/day-stats          day-stats
                        :query/started-tasks      started-tasks
                        :query/waiting-habits     waiting-habits
                        :query/mentions           mentions
                        :query/stories            stories
                        :query/sagas              sagas
                        :query/geo-photos         geo/photos-within-bounds
                        :query/custom-field-stats custom-field-stats
                        :query/git-stats          git-stats
                        :query/briefings          briefings
                        :query/questionnaires     questionnaires
                        :query/award-points       award-points
                        :query/briefing           briefing}))
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
