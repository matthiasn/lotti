(ns meins.jvm.graphql.exec
  "GraphQL query component"
  (:require [clojure.java.io :as io]
            [com.climate.claypoole :as cp]
            [com.walmartlabs.lacinia :as lacinia]
            [com.walmartlabs.lacinia.parser :as parser]
            [com.walmartlabs.lacinia.resolve :as resolve]
            [com.walmartlabs.lacinia.util :as lu]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.jvm.graphql.xforms :as xf]
            [meins.jvm.metrics :as mt]
            [metrics.timers :as tmr]
            [taoensso.timbre :refer [debug error info warn]])
  (:import [clojure.lang ExceptionInfo]))

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
      (error "GraphQL error" query error-result)
      (let [res (lacinia/execute-parsed-query-async parsed variables context)]
        (resolve/on-deliver! res on-deliver)))))

(def executor-thread-pool (cp/threadpool 5))
(def thread-pool (cp/priority-threadpool 3))
(def prio-thread-pool (cp/priority-threadpool 5))
(alter-var-root #'resolve/*callback-executor* (constantly executor-thread-pool))

(defn async-wrapper [f]
  (fn [state context args value]
    (let [result-promise (resolve/resolve-promise)
          p (:prio args 10)
          tp (if (< p 10)
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

(defn run-query [{:keys [cmp-state current-state msg-payload put-fn] :as m}]
  (let [start (stc/now)
        qid (:id msg-payload)
        merged (merge (get-in current-state [:queries qid]) msg-payload)
        {:keys [file args q id once]} merged
        started-timer (mt/start-timer ["graphql" "query" (name id)])
        schema (:schema current-state)
        template (if file (slurp (io/resource (str "queries/" file))) q)
        query-string (when template (apply format template args))
        on-deliver
        (fn [res]
          (try
            (let [size (count (pr-str res))
                  res (merge merged
                             (xf/simplify res)
                             {:ts   (stc/now)
                              :size size
                              :prio (:prio merged 100)})]
              (when-not once
                (swap! cmp-state assoc-in [:queries id] (dissoc res :data)))
              (info "GraphQL query" id "finished in" (- (stc/now) start) "ms "
                    (str "- '" (or file query-string) "'"))
              (put-fn (with-meta [:gql/res res] {:sente-uid :broadcast}))
              (tmr/stop started-timer))
            (catch Exception ex (error ex))))]
    (when-not once
      (swap! cmp-state assoc-in [:queries id] merged))
    (if query-string
      (execute-async schema query-string nil m {} on-deliver)
      (put-fn [:gql/res (merge msg-payload {:data {}})])))
  {})
