(ns meo.electron.renderer.log
  (:require [taoensso.encore :as enc]
            [taoensso.timbre :as timbre]))

(enable-console-print!)

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

; See https://github.com/ptaoussanis/timbre
(def timbre-config
  {:ns-whitelist [] #_["my-app.foo-ns"]
   :ns-blacklist [] #_["taoensso.*"]

   :middleware   [(middleware {"observer.view.ipc"   :info
                               "observer.view.store" :info
                               :all                  :info})]

   :appenders    {:console {:enabled? true
                            :fn       (fn [data]
                                        (let [{:keys [output_]} data
                                              formatted-output-str (force output_)]
                                          (println formatted-output-str)))}}})

(timbre/merge-config! timbre-config)
