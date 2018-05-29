(ns meo.jvm.log
  (:require [taoensso.timbre :as timbre :refer [info]]
            [taoensso.timbre.appenders.3rd-party.rolling :as tr]
            [taoensso.encore :as enc]))

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

(def filename (if (get (System/getenv) "PORT") "/tmp/meo.log" "./log/meo.log"))

(timbre/set-config!
  {:level          :info
   :timestamp-opts {:pattern "yyyy-MM-dd HH:mm:ss.SSS"}
   :appenders      {:rolling (tr/rolling-appender {:path filename})}})
