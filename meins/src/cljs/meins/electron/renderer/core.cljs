(ns meins.electron.renderer.core
  (:require [matthiasn.systems-toolbox-electron.ipc-renderer :as ipc]
            [matthiasn.systems-toolbox-sente.client :as sente]
            [matthiasn.systems-toolbox.scheduler :as sched]
            [matthiasn.systems-toolbox.switchboard :as sb]
            [meins.common.specs]
            [meins.electron.renderer.client-store :as store]
            [meins.electron.renderer.exec :as exec]
            [meins.electron.renderer.graphql :as gql]
            [meins.electron.renderer.log]
            [meins.electron.renderer.screenshot :as screenshot]
            [meins.electron.renderer.spellcheck :as spellcheck]
            [meins.electron.renderer.ui.re-frame :as rf]
            [taoensso.timbre :refer [debug error info]]))

(def sente-base-cfg
  {:sente-opts {:host     (.-iwwHOST js/window)
                :protocol "http:"}
   :opts       {:in-chan  [:buffer 100]
                :out-chan [:buffer 100]}})

(def sente-cfg
  (merge sente-base-cfg
         {:relay-types #{:entry/update :entry/save-initial :entry/trash :entry/sync
                         :import/photos :import/spotify :import/flight
                         :backend-cfg/save :import/git :metrics/get
                         :photos/gen-cache :export/geojson
                         :import/movie :entry/unlink :startup/progress?
                         :import/listen :spotify/play :import/gen-thumbs
                         :spotify/pause :cfg/refresh :state/persist
                         :sync/start-server :sync/stop-server :gql/remove
                         :tf/learn-stories :gql/query :search/remove
                         :gql/cmd :firehose/cmd :playground/gen}}))

(def OBSERVER (.-OBSERVER js/window))

(defn make-observable [components]
  (if OBSERVER
    (let [mapper #(assoc-in % [:opts :msgs-on-firehose] true)]
      (set (mapv mapper components)))
    components))

(def ipc-relay-types #{:wm/open-external
                       :geonames/lookup
                       :crypto/get-cfg
                       :window/hide
                       :window/show
                       :window/progress
                       :file/encrypt
                       :imap/get-status
                       :imap/get-cfg
                       :imap/save-cfg
                       :sync/imap
                       :sync/start-imap
                       :help/get-manual
                       :import/screenshot
                       :update/check :update/check-beta :update/download
                       :update/install :window/close
                       :blink/busy
                       :crypto/create-keys})

(defonce switchboard (sb/component :renderer/switchboard))

(def components
  #{(ipc/cmp-map :renderer/ipc-cmp ipc-relay-types)
    (spellcheck/cmp-map :renderer/spellcheck)
    (screenshot/cmp-map :renderer/screenshot)
    (sente/cmp-map :renderer/ws-cmp sente-cfg)
    (when OBSERVER
      (sente/cmp-map :renderer/ws-firehose sente-base-cfg))
    (store/cmp-map :renderer/store)
    (sched/cmp-map :renderer/scheduler)
    (rf/cmp-map :renderer/ui-cmp)
    (exec/cmp-map :renderer/exec-cmp)})

(defn ^:dev/after-load init []
  (info "Starting SYSTEM")
  (let [components (make-observable components)]
    (sb/send-mult-cmd
      switchboard
      [[:cmd/init-comp components]

       [:cmd/route {:from :renderer/ipc-cmp
                    :to   #{:renderer/exec-cmp
                            :renderer/store
                            :renderer/screenshot
                            :renderer/spellcheck
                            :renderer/ws-cmp}}]

       [:cmd/route {:from :renderer/exec-cmp
                    :to   #{:renderer/ws-cmp
                            :renderer/store}}]

       [:cmd/route {:from #{:renderer/screenshot
                            :renderer/ui-cmp}
                    :to   :renderer/scheduler}]

       [:cmd/route {:from :renderer/scheduler
                    :to   #{:renderer/ipc-cmp
                            :renderer/screenshot
                            :renderer/ws-cmp
                            :renderer/store}}]

       [:cmd/route {:from :renderer/store
                    :to   #{:renderer/scheduler}}]

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
                            :renderer/ws-cmp
                            :renderer/store}}]

       [:cmd/observe-state {:from :renderer/store
                            :to   :renderer/ui-cmp}]

       (when OBSERVER
         [:cmd/attach-to-firehose :renderer/ws-firehose])

       [:cmd/send {:to  :renderer/store
                   :msg [:startup/query]}]

       [:cmd/send {:to  :renderer/scheduler
                   :msg [:schedule/new {:timeout (* 24 60 60 1000)
                                        :message (gql/usage-query)
                                        :repeat  true
                                        :initial true}]}]])))

(defn load-handler [_ev]
  (info "RENDERER loaded")
  (init))

(defn main []
  (.addEventListener js/window "load" load-handler))
