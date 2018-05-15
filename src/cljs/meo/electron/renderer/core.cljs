(ns meo.electron.renderer.core
  (:require [meo.common.specs]
            [meo.electron.renderer.log]
            [meo.electron.renderer.client-store :as store]
            [meo.electron.renderer.ui.re-frame :as rf]
            [meo.electron.renderer.router :as router]
            [meo.electron.renderer.tensorflow :as tf]
            [meo.electron.renderer.screenshot :as screenshot]
            [meo.electron.renderer.spellcheck :as spellcheck]
            [taoensso.timbre :refer-macros [info debug error]]
            [matthiasn.systems-toolbox-electron.ipc-renderer :as ipc]
            [matthiasn.systems-toolbox-sente.client :as sente]
            [meo.electron.renderer.exec :as exec]
            [cljs.nodejs :as nodejs :refer [process]]
            [matthiasn.systems-toolbox.switchboard :as sb]
            [matthiasn.systems-toolbox.scheduler :as sched]))

(defonce switchboard (sb/component :renderer/switchboard))

(def sente-base-cfg
  {:sente-opts {:host     (.-iwwHOST js/window)
                :protocol "http:"}
   :opts       {:in-chan  [:buffer 100]
                :out-chan [:buffer 100]}})

(def sente-cfg
  (merge sente-base-cfg
         {:relay-types #{:entry/update :entry/trash :entry/sync
                         :import/photos :import/spotify :import/flight
                         :import/screenshot :backend-cfg/save
                         :photos/gen-cache :export/geojson
                         :import/movie :entry/unlink :startup/progress?
                         :import/listen :spotify/play
                         :spotify/pause :cfg/refresh
                         :sync/start-server :sync/stop-server
                         :tf/learn-stories :gql/query}}))

(def OBSERVER (.-OBSERVER js/window))

(defn make-observable [components]
  (if OBSERVER
    (let [mapper #(assoc-in % [:opts :msgs-on-firehose] true)]
      (set (mapv mapper components)))
    components))

(def ipc-relay-types #{:wm/open-external
                       :geonames/lookup
                       :window/hide
                       :window/show
                       :window/progress
                       :file/encrypt
                       :blink/busy})

(defn start []
  (info "Starting SYSTEM")
  (let [components #{(ipc/cmp-map :renderer/ipc-cmp ipc-relay-types)
                     (spellcheck/cmp-map :renderer/spellcheck)
                     (screenshot/cmp-map :renderer/screenshot)
                     (sente/cmp-map :renderer/ws-cmp sente-cfg)
                     (tf/cmp-map :renderer/tensorflow)
                     (when OBSERVER
                       (sente/cmp-map :renderer/ws-firehose sente-base-cfg))
                     (router/cmp-map :renderer/router)
                     (store/cmp-map :renderer/store)
                     (sched/cmp-map :renderer/scheduler)
                     (rf/cmp-map :renderer/ui-cmp)
                     (exec/cmp-map :renderer/exec-cmp #{})}
        components (make-observable components)]
    (sb/send-mult-cmd
      switchboard
      [[:cmd/init-comp components]

       [:cmd/route {:from :renderer/ipc-cmp
                    :to   #{:renderer/exec-cmp
                            :renderer/store
                            :renderer/screenshot
                            :renderer/spellcheck
                            :renderer/ws-cmp}}]

       [:cmd/route {:from #{:renderer/router}
                    :to   :renderer/store}]

       [:cmd/route {:from #{:renderer/screenshot
                            :renderer/ui-cmp}
                    :to   :renderer/scheduler}]

       [:cmd/route {:from :renderer/scheduler
                    :to   #{:renderer/ipc-cmp
                            :renderer/screenshot
                            :renderer/ws-cmp
                            :renderer/store}}]

       [:cmd/route {:from :renderer/store
                    :to   #{:renderer/router
                            :renderer/scheduler}}]

       [:cmd/route {:from #{:renderer/ui-cmp
                            :renderer/store}
                    :to   #{:renderer/ws-cmp
                            :renderer/ipc-cmp}}]

       [:cmd/route {:from #{:renderer/ui-cmp
                            :renderer/ws-cmp}
                    :to   #{:renderer/store
                            :renderer/screenshot
                            :renderer/ipc-cmp}}]

       [:cmd/route {:from :renderer/screenshot
                    :to   #{:renderer/ipc-cmp
                            :renderer/store}}]

       [:cmd/observe-state {:from :renderer/store
                            :to   :renderer/ui-cmp}]

       [:cmd/observe-state {:from :renderer/store
                            :to   :renderer/screenshot}]

       (when OBSERVER
         [:cmd/attach-to-firehose :renderer/ws-firehose])

       [:cmd/send {:to  :renderer/store
                   :msg [:startup/query]}]])))

(defn load-handler [ev]
  (info "RENDERER loaded")
  (start))

(.addEventListener js/window "load" load-handler)
