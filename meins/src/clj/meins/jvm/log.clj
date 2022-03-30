(ns meins.jvm.log
  (:require [taoensso.encore :as enc]
            [taoensso.timbre :as timbre :refer [info]]
            [taoensso.timbre.appenders.3rd-party.rolling :as tr]
            [taoensso.timbre.appenders.core :as appenders]))

(defn ns-filter
  "From: https://github.com/yonatane/timbre-ns-pattern-level"
  [fltr]
  (-> fltr enc/compile-ns-filter taoensso.encore/memoize_))

(def namespace-log-levels
  {:all :info})

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

(def filename (if-let [logfile (get (System/getenv) "LOG_FILE")]
                logfile
                "./log/meins.log"))

(def spit-appender
  (merge
    (appenders/spit-appender {:fname "/tmp/"})
    {:async? true}))

(timbre/set-config!
  {:level          :info
   :timestamp-opts {:pattern "yyyy-MM-dd HH:mm:ss.SSS"}
   :appenders      {:rolling (tr/rolling-appender {:path filename})
                    ;                    :spit    spit-appender
                    }})
