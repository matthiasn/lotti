(ns meo.jvm.log
  (:require [taoensso.timbre :as timbre :refer [info]]
            [taoensso.timbre.appenders.core :as appenders]
            [taoensso.encore :as enc]
            [clojure.string :as s]))

(defn ns-filter
  "From: https://github.com/yonatane/timbre-ns-pattern-level"
  [fltr]
  (-> fltr enc/compile-ns-filter taoensso.encore/memoize_))

(def namespace-log-levels
  {"taoensso.sente" :trace
   :all             :info})

(defn middleware
  "From: https://github.com/yonatane/timbre-ns-pattern-level"
  [ns-patterns]
  (fn log-by-ns-pattern [{:keys [?ns-str config level] :as opts}]
    (let [namesp (or (some->> ns-patterns
                              keys
                              (filter #(and (string? %)
                                            ((ns-filter %) ?ns-str)))
                              not-empty
                              (apply max-key count))
                     :all)
          log-level (get ns-patterns namesp (get config :level))]
      (when (and (taoensso.timbre/may-log? log-level namesp)
                 (taoensso.timbre/level>= level log-level))
        opts))))

; See https://github.com/ptaoussanis/timbre
(def timbre-config
  {:level          :trace
   :timestamp-opts {:pattern "yyyy-MM-dd HH:mm:ss.SSS"}
   :middleware     [(middleware namespace-log-levels)]
   :appenders      {:spit (appenders/spit-appender
                            {:fname          "/tmp/meo.log"
                             :hostname_      "foo"
                             :timestamp-opts {:pattern "yyyy-MM-dd HH:mm:ss.SSSZ"}})}})

(timbre/merge-config! timbre-config)
