(ns meo.ios.core
  (:require [reagent.core :as r :refer [atom]]
            [re-frame.core :refer [subscribe dispatch dispatch-sync]]
            [meo.events]
            [meo.ios.healthkit :as hk]
            [meo.ios.store :as store]
            [meo.ui :as ui]
            [meo.helpers :as h]
            [matthiasn.systems-toolbox.switchboard :as sb]
            [matthiasn.systems-toolbox-sente.client :as sente]
            [matthiasn.systems-toolbox.scheduler :as sched]
            [meo.subs]
            [meo.utils.parse :as p]
            [matthiasn.systems-toolbox.component :as st]
            [clojure.pprint :as pp]))

(enable-console-print!)

(defonce switchboard (sb/component :client/switchboard))

(def OBSERVER true)

(defn make-observable [components]
  (if OBSERVER
    (let [mapper #(assoc-in % [:opts :msgs-on-firehose] true)]
      (println "CORE: Attaching firehose")
      (set (mapv mapper components)))
    components))

(def sente-cfg {:relay-types #{:entry/update :entry/find :entry/trash
                               :import/geo :import/photos :import/phone
                               :import/spotify :import/flight :export/pdf
                               :stats/pomo-day-get :import/screenshot :healthkit/steps
                               :stats/get :stats/get2 :import/movie :blink/busy
                               :state/stats-tags-get :import/weight :import/listen
                               :state/search :cfg/refresh :firehose/cmp-recv
                               :firehose/cmp-put}
                :sente-opts  {:host "192.168.2.106:8765"}})

(defn init []
  (dispatch-sync [:initialize-db])
  (let [components #{(sente/cmp-map :app/ws-cmp sente-cfg)
                     (store/cmp-map :app/store)
                     (hk/cmp-map :app/healthkit)
                     (sched/cmp-map :app/scheduler)
                     (ui/cmp-map :app/ui-cmp)}
        components (make-observable components)]
    (sb/send-mult-cmd
      switchboard
      [[:cmd/init-comp components]

       [:cmd/route {:from #{:app/store
                            :app/healthkit
                            :app/ui-cmp}
                    :to   :app/ws-cmp}]

       [:cmd/route {:from :app/healthkit
                    :to   :app/ws-cmp}]

       [:cmd/route {:from #{:app/ws-cmp
                            :app/healthkit
                            :app/ui-cmp}
                    :to   :app/store}]

       [:cmd/route {:from #{:app/ws-cmp
                            :app/ui-cmp}
                    :to   :app/store}]

       [:cmd/route {:from :app/ui-cmp
                    :to   :app/healthkit}]

       [:cmd/observe-state {:from :app/store
                            :to   :app/ui-cmp}]

       (when OBSERVER
         [:cmd/attach-to-firehose :app/ws-cmp])

       [:cmd/route {:from :app/scheduler
                    :to   #{:app/store
                            :app/ws-cmp}}]])))
