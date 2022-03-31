(ns meins.jvm.metrics
  (:require [metrics.core :as mc]
            [metrics.histograms :as hist]
            [metrics.timers :as tmr]
            [taoensso.timbre :refer [debug error info warn]]))

(def metrics-registry (mc/new-registry))

(defn start-timer [id-vec]
  (let [my-timer (tmr/timer metrics-registry id-vec)
        started (tmr/start my-timer)]
    started))

(defn active-timers []
  (let [timers (mc/timers metrics-registry)
        f (fn [[metric timer]]
            (let [perc (into {} (map (fn [[k v]] [k (/ v 1E6)])
                                     (tmr/percentiles timer)))]
              [metric {:percentiles perc
                       :mean        (/ (tmr/mean timer) 1E6)
                       :smallest    (/ (tmr/smallest timer) 1E6)
                       :largest     (/ (tmr/largest timer) 1E6)
                       :std-dev     (/ (hist/std-dev timer) 1E6)
                       :n           (tmr/number-recorded timer)}]))]
    (into {} (map f timers))))

(defn get-metrics [{:keys [put-fn]}]
  (put-fn [:metrics/info (active-timers)]))