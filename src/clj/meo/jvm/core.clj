(ns meo.jvm.core
  "In this namespace, the individual components are initialized and wired
  together to form the backend system."
  (:gen-class)
  (:require [matthiasn.systems-toolbox.switchboard :as sb]
            [matthiasn.systems-toolbox-sente.server :as sente]
            [matthiasn.systems-toolbox.scheduler :as sched]
            [meo.jvm.index :as idx]
            [meo.common.specs]
            [clj-pid.core :as pid]
            [meo.jvm.log]
            ;[matthiasn.systems-toolbox-kafka.kafka-producer2 :as kp2]
            [meo.jvm.store :as st]
            [meo.jvm.fulltext-search :as ft]
            [meo.jvm.upload :as up]
            [meo.jvm.backup :as bak]
            [meo.jvm.imports :as i]
            [taoensso.timbre :refer [info]]))

(defonce switchboard (sb/component :server/switchboard))

#_(defn make-observable [components]
    (if (System/getenv "OBSERVER")
      (let [cfg {:cfg         {:bootstrap-servers "localhost:9092"
                               :auto-offset-reset "latest"
                               :topic             "firehose"}
                 :relay-types #{:firehose/cmp-put
                                :firehose/cmp-publish-state
                                :firehose/cmp-recv}}
            mapper #(assoc-in % [:opts :msgs-on-firehose] true)
            components (set (mapv mapper components))
            firehose-kafka (kp2/cmp-map :server/kafka-firehose cfg)]
        (conj components firehose-kafka))
      components))

(defn restart!
  "Starts or restarts system by asking switchboard to fire up the ws-cmp for
   serving the client side application and providing bi-directional
   communication with the client, plus the store and imports components.
   Then, routes messages to the store and imports components for which those
   have a handler function. Also route messages from imports to store component.
   Finally, sends all messages from store component to client via the ws
   component."
  [switchboard]
  (let [components #{(sente/cmp-map :server/ws-cmp idx/sente-map)
                     (sched/cmp-map :server/scheduler-cmp)
                     (i/cmp-map :server/imports-cmp)
                     (st/cmp-map :server/store-cmp)
                     (bak/cmp-map :server/backup-cmp)
                     (up/cmp-map :server/upload-cmp switchboard)
                     (ft/cmp-map :server/ft-cmp)}
        ;components (make-observable components)
        ]
    (sb/send-mult-cmd
      switchboard
      [[:cmd/init-comp components]

       [:cmd/route {:from :server/ws-cmp
                    :to   #{:server/store-cmp
                            :server/export-cmp
                            :server/upload-cmp
                            :server/imports-cmp}}]

       [:cmd/route {:from :server/imports-cmp
                    :to   :server/store-cmp}]

       [:cmd/route {:from :server/upload-cmp
                    :to   #{:server/store-cmp
                            :server/scheduler-cmp
                            :server/ws-cmp}}]

       [:cmd/route {:from :server/store-cmp
                    :to   #{:server/ws-cmp
                            :server/ft-cmp}}]

       [:cmd/route {:from :server/scheduler-cmp
                    :to   #{:server/store-cmp
                            :server/backup-cmp
                            :server/imports-cmp
                            :server/upload-cmp
                            :server/ws-cmp}}]

       [:cmd/route {:from #{:server/store-cmp
                            :server/upload-cmp
                            :server/backup-cmp
                            :server/imports-cmp}
                    :to   :server/scheduler-cmp}]
       #_(when (System/getenv "OBSERVER")
           [:cmd/attach-to-firehose :server/kafka-firehose])

       [:cmd/send {:to  :server/scheduler-cmp
                   :msg [:cmd/schedule-new {:timeout (* 5 60 1000)
                                            :message [:import/spotify]
                                            :repeat  true
                                            :initial true}]}]])))

(defn -main
  "Starts the application from command line, saves and logs process ID. The
   system that is fired up when restart! is called proceeds in core.async's
   thread pool. Since we don't want the application to exit when the current
   thread is out of work, we just put it to sleep."
  [& _args]
  (pid/save "meo.pid")
  (pid/delete-on-shutdown! "meo.pid")
  (info "meo started, PID" (pid/current))
  (restart! switchboard)
  (Thread/sleep Long/MAX_VALUE))
