(ns meins.electron.main.log
  (:require ["electron-log" :as l]
            [cljs.nodejs :as nodejs]
            [meins.electron.main.runtime :as rt]
            [taoensso.encore :as enc]
            [taoensso.timbre :as timbre]))

(aset l "transports" "console" "level" "info")
(aset l "transports" "console" "format" "{h}:{i}:{s}:{ms} {text}")
(aset l "transports" "file" "level" "info")
(aset l "transports" "file" "format" "{h}:{i}:{s}:{ms} {text}")
(aset l "transports" "file" "file" (:logfile-electron rt/runtime-info))

(nodejs/enable-util-print!)

(defn ns-filter
  "From: https://github.com/yonatane/timbre-ns-pattern-level"
  [fltr]
  (-> fltr enc/compile-ns-filter taoensso.encore/memoize_))

(def namespace-log-levels
  {;"matthiasn.systems-toolbox-electron.window-manager" :debug
   :all :info})

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

(defn appender-fn [data]
  (let [{:keys [output_ level]} data
        formatted (force output_)]
    (case level
      :warn (l/warn formatted)
      :error (l/error formatted)
      (l/info formatted))))

; See https://github.com/ptaoussanis/timbre
(def timbre-config
  {:ns-whitelist [] #_["my-app.foo-ns"]
   :ns-blacklist [] #_["taoensso.*"]
   :middleware   [(middleware namespace-log-levels)]
   :appenders    {:console {:enabled? true
                            :fn       appender-fn}}})

(timbre/merge-config! timbre-config)
