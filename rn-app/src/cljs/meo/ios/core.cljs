(ns meo.ios.core
  (:require [re-frame.core :refer [subscribe dispatch dispatch-sync]]
            [meo.events]
            [meo.ios.healthkit :as hk]
            [meo.ios.sync :as sync]
            [meo.ios.store :as store]
            [meo.ios.photos :as photos]
            [meo.ui :as ui]
            [meo.ui.shared :refer [view text app-registry]]
            [matthiasn.systems-toolbox.switchboard :as sb]
            [matthiasn.systems-toolbox.scheduler :as sched]
            [meo.subs]
            [reagent.core :as r]))

(enable-console-print!)

(defonce switchboard (sb/component :client/switchboard))

(def OBSERVER false)

(defn make-observable [components]
  (if OBSERVER
    (let [mapper #(assoc-in % [:opts :msgs-on-firehose] true)]
      (println "CORE: Attaching firehose")
      (set (mapv mapper components)))
    components))

(defn init []
  (dispatch-sync [:initialize-db])
  (let [components #{(hk/cmp-map :app/healthkit)
                     (store/cmp-map :app/store)
                     (photos/cmp-map :app/photos)
                     (sync/cmp-map :app/sync)
                     (sched/cmp-map :app/scheduler)
                     (ui/cmp-map :app/ui-cmp)}
        components (make-observable components)]
    (sb/send-mult-cmd
      switchboard
      [[:cmd/init-comp components]

       [:cmd/route {:from #{:app/store
                            :app/ui-cmp}
                    :to :app/sync}]

       [:cmd/route {:from :app/sync
                    :to   #{:app/store
                            :app/scheduler}}]

       [:cmd/route {:from :app/healthkit
                    :to   :app/store}]

       [:cmd/route {:from :app/ui-cmp
                    :to   :app/store}]

       [:cmd/route {:from :app/ui-cmp
                    :to   :app/store}]

       [:cmd/route {:from :app/ui-cmp
                    :to   :app/photos}]

       [:cmd/route {:from :app/ui-cmp
                    :to   :app/healthkit}]

       [:cmd/observe-state {:from :app/store
                            :to   :app/ui-cmp}]

       (when OBSERVER
         [:cmd/attach-to-firehose :app/sync])

       [:cmd/route {:from :app/scheduler
                    :to   #{:app/store
                            :app/sync}}]

       [:cmd/send {:to  :app/scheduler
                   :msg [:cmd/schedule-new {:timeout 10000
                                            :message [:sync/fetch]
                                            :repeat  true
                                            :initial false}]}]

       [:cmd/send {:to  :app/scheduler
                   :msg [:cmd/schedule-new {:timeout (* 10 60 1000)
                                            :message [:sync/retry]
                                            :repeat  true
                                            :initial false}]}]])
    (.registerComponent
      app-registry "meo" #(r/reactify-component ui/app-root))))
