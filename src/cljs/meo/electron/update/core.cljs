(ns meo.electron.update.core
  (:require [meo.electron.update.log]
            [taoensso.timbre :as timbre :refer-macros [info debug]]
            [matthiasn.systems-toolbox-electron.ipc-renderer :as ipc]
            [matthiasn.systems-toolbox.switchboard :as sb]
            [meo.electron.update.ui :as ui]))

(defonce switchboard (sb/component :updater/switchboard))

(def relay-types #{:update/check :update/check-beta :update/download
                   :update/install :window/close})

(defn start []
  (info "Starting UPDATER")
  (sb/send-mult-cmd
    switchboard
    [[:cmd/init-comp #{(ipc/cmp-map :updater/ipc-cmp relay-types)
                       (ui/cmp-map :updater/ui-cmp)}]

     [:cmd/route {:from :updater/ipc-cmp
                  :to   #{:updater/ui-cmp}}]

     [:cmd/route {:from :updater/ui-cmp
                  :to   #{:updater/ipc-cmp}}]]))

(.addEventListener js/window "load" #(start))
