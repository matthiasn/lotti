(ns meo.electron.geocoder.core
  (:require [meo.electron.geocoder.log]
            [meo.electron.geocoder.ipc :as ipc]
            [electron-log :as l]
            [meo.common.specs]
            [meo.electron.geocoder.geonames :as geonames]
            [taoensso.timbre :as timbre :refer-macros [info]]
            [matthiasn.systems-toolbox.scheduler :as sched]
            [matthiasn.systems-toolbox.switchboard :as sb]
            [cljs.nodejs :as nodejs :refer [process]]))

(nodejs/enable-util-print!)

(when-not (aget js/goog "global" "setTimeout")
  (info "goog.global.setTimeout not defined - let's change that")
  (aset js/goog "global" "setTimeout" js/setTimeout))

(defonce switchboard (sb/component :geocoder/switchboard))

(def OBSERVER true)

(defn make-observable
  [components]
  (if OBSERVER
    (let [mapper #(assoc-in % [:opts :msgs-on-firehose] true)]
      (set (mapv mapper components)))
    components))

(defn start []
  (info "Starting geonames CORE")
  (let [components #{(geonames/cmp-map :geocoder/service)
                     (ipc/cmp-map :geocoder/ipc #{:geonames/res
                                                  :firehose/cmp-put
                                                  :firehose/cmp-recv})}
        components (make-observable components)]
    (sb/send-mult-cmd
      switchboard
      [[:cmd/init-comp components]

       [:cmd/route {:from :geocoder/service
                    :to   :geocoder/ipc}]
       [:cmd/route {:from :geocoder/ipc
                    :to   :geocoder/service}]

       (when OBSERVER
         [:cmd/attach-to-firehose :geocoder/ipc])])))

(start)
