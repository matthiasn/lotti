(ns meins.electron.main.core
  (:require ["electron-context-menu" :as context-menu]
            [cljs.nodejs :as nodejs :refer [process]]
            [cljs.pprint :as pp]
            [electron :refer [app]]
            [matthiasn.systems-toolbox-electron.ipc-main :as ipc]
            [matthiasn.systems-toolbox-electron.window-manager :as wm]
            [matthiasn.systems-toolbox.scheduler :as sched]
            [matthiasn.systems-toolbox.switchboard :as sb]
            [meins.common.specs]
            [meins.electron.main.crypto :as kc]
            [meins.electron.main.import :as ai]
            [meins.electron.main.imap :as imap]
            [meins.electron.main.log]
            [meins.electron.main.menu :as menu]
            [meins.electron.main.runtime :as rt]
            [meins.electron.main.screenshot :as screen]
            [meins.electron.main.startup :as st]
            [meins.electron.main.update :as upd]
            [taoensso.timbre :refer [info]]))

(aset process "env" "GOOGLE_API_KEY" "AIzaSyD78NTnhgt--LCGBdIGPEg8GtBYzQl0gKU")

(defonce switchboard (sb/component :main/switchboard))

(def OBSERVER (:repo-dir rt/runtime-info))

(defn make-observable [components]
  (if OBSERVER
    (let [mapper #(assoc-in % [:opts :msgs-on-firehose] true)]
      (set (mapv mapper components)))
    components))

(context-menu (clj->js {:showCopyImageAddress true
                        :showInspectElement   true}))

(def wm-relay #{:cmd/toggle-key
                :update/status
                :screenshot/save
                :entry/update
                :entry/sync
                :entry/create
                :geonames/res
                :crypto/cfg
                :export/geojson
                :gql/cmd
                :firehose/cmd
                :tf/learn-stories
                :search/cmd
                :spellcheck/lang
                :spellcheck/off
                :state/persist
                :imap/status
                :imap/cfg
                :import/gen-thumbs
                :import/photos
                :import/listen
                :import/spotify
                :import/git
                :nav/to
                :playground/gen
                :firehose/cmp-put
                :firehose/cmp-recv})

(def app-path (:app-path rt/runtime-info))

(defn start []
  (info "Starting CORE:" (with-out-str (pp/pprint rt/runtime-info)))
  (let [components #{(wm/cmp-map :main/window-manager wm-relay app-path)
                     (st/cmp-map :main/startup)
                     (ipc/cmp-map :main/ipc-cmp)
                     (screen/cmp-map :main/screenshot)
                     (imap/cmp-map :main/sync)
                     (kc/cmp-map :main/crypto)
                     (ai/cmp-map :main/audio-import (:audio-path rt/runtime-info))
                     (upd/cmp-map :main/updater)
                     (sched/cmp-map :main/scheduler)
                     (menu/cmp-map :main/menu-cmp)}
        components (make-observable components)]
    (sb/send-mult-cmd
      switchboard
      [[:cmd/init-comp components]

       [:cmd/route {:from :main/menu-cmp
                    :to   #{:main/window-manager
                            :main/startup
                            :main/audio-import
                            :main/scheduler
                            :main/screenshot
                            :main/updater}}]

       [:cmd/route {:from :main/scheduler
                    :to   #{:main/updater
                            :main/window-manager
                            :main/menu-cmp
                            :main/sync
                            :main/startup}}]

       [:cmd/route {:from :main/ipc-cmp
                    :to   #{:main/startup
                            :main/updater
                            :main/crypto
                            :main/screenshot
                            :main/sync
                            :main/scheduler
                            :main/window-manager}}]

       [:cmd/route {:from :main/window-manager
                    :to   :main/startup}]

       [:cmd/route {:from :main/crypto
                    :to   #{:main/window-manager
                            :main/sync}}]

       [:cmd/route {:from :main/screenshot
                    :to   :main/window-manager}]

       [:cmd/route {:from :main/audio-import
                    :to   :main/window-manager}]

       [:cmd/route {:from :main/sync
                    :to   #{:main/window-manager
                            :main/scheduler}}]

       [:cmd/route {:from :main/updater
                    :to   #{:main/scheduler
                            :main/window-manager
                            :main/startup}}]

       [:cmd/route {:from :main/startup
                    :to   #{:main/scheduler
                            :main/window-manager}}]

       (when OBSERVER
         [:cmd/attach-to-firehose :main/window-manager])

       [:cmd/send {:to :main/startup :msg [:jvm/loaded? {:environment :live}]}]

       [:cmd/send {:to  :main/scheduler
                   :msg [:schedule/new {:timeout (* 24 60 60 1000)
                                        :message [:update/auto-check]
                                        :repeat  true
                                        :initial true}]}]])))

(.on app "ready" start)
(.on app "activate" (fn [_ev hasVisibleWindows]
                      (when-not hasVisibleWindows
                        (start))))

(defn init [])
