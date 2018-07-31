(ns meo.ios.core
  (:require [re-frame.core :refer [subscribe dispatch dispatch-sync]]
            [meo.events]
            [meo.ios.healthkit :as hk]
            [meo.ios.activity :as ac]
            [meo.ios.ws :as ws]
            [meo.ios.sync :as sync]
            [meo.ios.store :as store]
            [meo.ui :as ui]
            [meo.ui.shared :refer [view text app-registry]]
            [matthiasn.systems-toolbox.switchboard :as sb]
            [matthiasn.systems-toolbox.scheduler :as sched]
            [meo.subs]
            [reagent.core :as r]))

(enable-console-print!)

(defonce switchboard (sb/component :client/switchboard))

(def OBSERVER true)

(defn make-observable [components]
  (if OBSERVER
    (let [mapper #(assoc-in % [:opts :msgs-on-firehose] true)]
      (println "CORE: Attaching firehose")
      (set (mapv mapper components)))
    components))

(def sente-cfg
  {:relay-types #{:entry/update :entry/find :entry/trash :sync/entry :sync/done
                  :import/geo :import/photos :import/phone
                  :import/spotify :import/flight :export/pdf
                  :stats/pomo-day-get :import/screenshot :healthkit/steps
                  :stats/get :stats/get2 :import/movie :blink/busy
                  :state/stats-tags-get :import/weight :import/listen
                  :state/search :cfg/refresh :firehose/cmp-recv
                  :firehose/cmp-put}})

(defn init []
  (dispatch-sync [:initialize-db])
  (let [components #{(ws/cmp-map :app/ws sente-cfg)
                     (hk/cmp-map :app/healthkit)
                     (ac/cmp-map :app/activity)
                     (store/cmp-map :app/store)
                     (sync/cmp-map :app/sync)
                     (sched/cmp-map :app/scheduler)
                     (ui/cmp-map :app/ui-cmp)}
        components (make-observable components)]
    (sb/send-mult-cmd
      switchboard
      [[:cmd/init-comp components]

       [:cmd/route {:from :app/store
                    :to   #{:app/ws
                            :app/sync}}]

       [:cmd/route {:from :app/ui-cmp
                    :to   :app/ws}]

       [:cmd/route {:from :app/healthkit
                    :to   :app/ws}]

       [:cmd/route {:from :app/healthkit
                    :to   :app/store}]

       [:cmd/route {:from :app/activity
                    :to   :app/store}]

       [:cmd/route {:from :app/ws
                    :to   :app/store}]

       [:cmd/route {:from :app/ui-cmp
                    :to   :app/store}]

       [:cmd/route {:from :app/ui-cmp
                    :to   :app/healthkit}]

       [:cmd/route {:from :app/ui-cmp
                    :to   :app/activity}]

       [:cmd/observe-state {:from :app/store
                            :to   :app/ui-cmp}]

       (when OBSERVER
         [:cmd/attach-to-firehose :app/ws])

       [:cmd/route {:from :app/scheduler
                    :to   #{:app/store
                            :app/ws}}]])
    (.registerComponent
      app-registry "meo" #(r/reactify-component ui/app-root))))
