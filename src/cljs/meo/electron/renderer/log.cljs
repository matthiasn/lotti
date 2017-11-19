(ns meo.electron.renderer.log
  (:require [taoensso.encore :as enc]
            [electron-log :as l]
            [taoensso.timbre :as timbre]))

(defn ns-filter
  "From: https://github.com/yonatane/timbre-ns-pattern-level"
  [fltr]
  (-> fltr enc/compile-ns-filter taoensso.encore/memoize_))

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
  {:middleware [(middleware {"meo.electron.main.core" :info
                             :all                     :info})]
   :appenders  {:console {:enabled? true
                          :fn       appender-fn}}})

(timbre/merge-config! timbre-config)
