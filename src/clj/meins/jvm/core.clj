(ns meins.jvm.core
  "In this namespace, the individual components are initialized and wired
  together to form the backend system."
  (:gen-class)
  (:require [clj-pid.core :as pid]
            [clojure.string :as s]
            [matthiasn.systems-toolbox-sente.server :as sente]
            [matthiasn.systems-toolbox.scheduler :as sched]
            [matthiasn.systems-toolbox.switchboard :as sb]
            [meins.common.specs]
            [meins.common.utils.misc :refer [connect]]
            [meins.jvm.file-utils :as fu]
            [meins.jvm.firehose :as fh]
            [meins.jvm.fulltext-search :as ft]
            [meins.jvm.imports :as i]
            [meins.jvm.index :as idx]
            [meins.jvm.log]
            [meins.jvm.playground :as pg]
            [meins.jvm.store :as st]
            [taoensso.timbre :refer [info]]))

(defonce switchboard (sb/component :backend/switchboard))

(def cmp-maps
  #{(sente/cmp-map :backend/ws idx/sente-map)
    (sched/cmp-map :backend/scheduler)
    (i/cmp-map :backend/imports)
    (st/cmp-map :backend/store)
    (pg/cmp-map :backend/playground)
    (ft/cmp-map :backend/ft)})

(defn make-observable [components]
  (set (conj (mapv #(assoc-in % [:opts :msgs-on-firehose] true) components)
             (fh/firehose-cmp :backend/firehose))))

(defn restart!
  "Starts or restarts system by asking switchboard to fire up the ws-cmp for
   serving the client side application and providing bi-directional
   communication with the client, plus the store and imports components.
   Then, routes messages to the store and imports components for which those
   have a handler function. Also route messages from imports to store component.
   Finally, sends all messages from store component to client via the ws
   component."
  [opts]
  (sb/send-mult-cmd
    switchboard
    [[:cmd/init-comp (make-observable cmp-maps)]

     (connect :backend/ws :backend/store)
     (connect :backend/ws :backend/export)
     (connect :backend/ws :backend/playground)
     (connect :backend/ws :backend/imports)

     (connect :backend/imports :backend/store)
     (connect :backend/imports :backend/ws)
     (connect :backend/imports :backend/scheduler)

     (connect :backend/playground :backend/store)

     (connect :backend/store :backend/ws)
     (connect :backend/store :backend/ft)
     (connect :backend/store :backend/scheduler)

     (connect :backend/scheduler :backend/store)
     (connect :backend/scheduler :backend/imports)
     (connect :backend/scheduler :backend/ws)

     [:cmd/attach-to-firehose :backend/firehose]

     (when (:read-logs opts)
       [:cmd/send {:to  :backend/store
                   :msg [:startup/read]}])

     (when-not (System/getenv "DATA_PATH")
       [:cmd/send {:to  :backend/store
                   :msg [:gql/cmd {:cmd :start}]}])

     (when-not (s/includes? fu/data-path "playground")
       [:cmd/send {:to  :backend/scheduler
                   :msg [:schedule/new {:timeout (* 5 60 1000)
                                        :message [:import/spotify]
                                        :repeat  true
                                        :initial false}]}])]))

(defn -main
  "Starts the application from command line, saves and logs process ID. The
   system that is fired up when restart! is called proceeds in core.async's
   thread pool. Since we don't want the application to exit when the current
   thread is out of work, we just put it to sleep."
  [& _args]
  (pid/save fu/pid-file)
  (pid/delete-on-shutdown! fu/pid-file)
  (info "meins started, PID" (pid/current))
  (restart! {:read-logs true})
  (Thread/sleep Long/MAX_VALUE))
