(ns meins.electron.renderer.log
  (:require [electron-log :as l]
            [taoensso.encore :as enc]
            [taoensso.timbre :as timbre]))

(enable-console-print!)

(defn ns-filter
  "From: https://github.com/yonatane/timbre-ns-pattern-level"
  [fltr]
  (-> fltr enc/compile-ns-filter taoensso.encore/memoize_))

(defonce ns-patterns
         (atom {"meins.electron.main.core" :info
                :all                     :info}))

;; meins.electron.renderer.log.set_log_level("meins.electron.renderer.ui.draft", "info")
(defn ^:export set-log-level
  "Set log level for a given namespace from the electron console, see example
   above."
  [ns lvl]
  (let [level (case lvl
                "info" :info
                "warn" :warn
                "debug" :debug
                "trace" :trace
                nil)]
    (when level
      (swap! ns-patterns assoc-in [ns] level))
    (if level
      (println "log level" level "set for namespace" ns)
      (println "ERROR:" lvl "is not a currently defined log level"))
    nil))

;; adapted from https://github.com/yonatane/timbre-ns-pattern-level
(defn log-by-ns-pattern [{:keys [?ns-str config level] :as opts}]
  (let [namesp (or (some->> @ns-patterns
                            keys
                            (filter #(and (string? %)
                                          ((ns-filter %) ?ns-str)))
                            not-empty
                            (apply max-key count))
                   :all)
        log-level (get @ns-patterns namesp (get config :level))]
    (when (and (taoensso.timbre/may-log? log-level namesp)
               (taoensso.timbre/level>= level log-level))
      opts)))

(defn appender-fn [data]
  (let [{:keys [output_ level]} data
        formatted (force output_)]
    (case level
      :warn (l/warn formatted)
      :error (l/error formatted)
      (l/info formatted))))

; See https://github.com/ptaoussanis/timbre
(def timbre-config
  {:middleware [log-by-ns-pattern]
   :appenders  {:console {:enabled? true
                          :fn       appender-fn}}})

(timbre/merge-config! timbre-config)
