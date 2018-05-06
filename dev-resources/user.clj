(ns user
  (:require
    [matthiasn.systems-toolbox-kafka.kafka-producer2 :as kp2]
    [taoensso.timbre :refer [info]])
  (:use [meo.jvm.core]))

(defn make-observable [components]
  (let [cfg {:cfg         {:bootstrap-servers "localhost:9092"
                           :auto-offset-reset "latest"
                           :topic             "firehose"}
             :relay-types #{:firehose/cmp-put
                            :firehose/cmp-publish-state
                            :firehose/cmp-recv}}
        mapper #(assoc-in % [:opts :msgs-on-firehose] true)
        components (set (mapv mapper components))
        firehose-kafka (kp2/cmp-map :backend/kafka-firehose cfg)]
    (conj components firehose-kafka)))

(defn start-meo
  ([] (start-meo false))
  ([inspect]
   (if inspect
     (restart! switchboard (make-observable cmp-maps) {:inspect   true
                                                       :read-logs true})
     (restart! switchboard cmp-maps {:read-logs true}))))

(defn reload-meo
  ([] (reload-meo false))
  ([inspect]
   (if inspect
     (restart! switchboard (make-observable cmp-maps) {:inspect true})
     (restart! switchboard cmp-maps {}))))
