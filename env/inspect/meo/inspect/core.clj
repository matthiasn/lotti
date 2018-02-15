(ns meo.inspect.core
  (:require
    [matthiasn.systems-toolbox-kafka.kafka-producer2 :as kp2]
    [taoensso.timbre :refer [info]]
    [meo.jvm.core :as mjc]
    [clj-pid.core :as pid]))

(defn make-observable [components]
  (let [cfg {:cfg         {:bootstrap-servers "localhost:9092"
                           :auto-offset-reset "latest"
                           :topic             "firehose"}
             :relay-types #{:firehose/cmp-put
                            :firehose/cmp-publish-state
                            :firehose/cmp-recv}}
        mapper #(assoc-in % [:opts :msgs-on-firehose] true)
        components (set (mapv mapper components))
        firehose-kafka (kp2/cmp-map :server/kafka-firehose cfg)]
    (conj components firehose-kafka)))

(defn -main
  "Starts the application from command line, with the firehose connected to a
   kafka producer that emits all of the application's events for consumption
   in inspect."
  [& _args]
  (info "meo with inspect started, PID" (pid/current))
  (mjc/restart! mjc/switchboard (make-observable mjc/cmp-maps) true)
  (Thread/sleep Long/MAX_VALUE))
