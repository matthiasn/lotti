(ns meins.core
  (:require ["react-native" :refer [AppRegistry Platform StyleSheet Text View Icon]]
            ["react" :as react :refer [Component]]
            [reagent.core :as r]
            ["react-navigation" :refer [createStackNavigator createAppContainer
                                        createBottomTabNavigator]]
            [cljs.pprint :as pp]
            [meins.ui.shared :refer [view text fa-icon]]
            [meins.ui.settings :as s]
            [meins.store :as st]
            [meins.ui.editor :as ue]
            [re-frame.core :refer [reg-sub subscribe dispatch dispatch-sync]]
            [meins.ios.sync :as sync]
            [meins.store :as store]
    ;[meo.ios.photos :as photos]
            [meins.ui :as ui]
            [matthiasn.systems-toolbox.switchboard :as sb]
            [matthiasn.systems-toolbox.scheduler :as sched]
            [meins.ios.healthkit :as hk]))

(enable-console-print!)
(defonce switchboard (sb/component :client/switchboard))
(def OBSERVER false)

(defn make-observable [components]
  (if OBSERVER
    (let [mapper #(assoc-in % [:opts :msgs-on-firehose] true)]
      (println "CORE: Attaching firehose")
      (set (mapv mapper components)))
    components))

(defn ^:dev/after-load init []
  ;(dispatch-sync [:initialize-db])
  (let [components #{(hk/cmp-map :app/healthkit)
                     (store/cmp-map :app/store)
                     ;(photos/cmp-map :app/photos)
                     (sync/cmp-map :app/sync)
                     (sched/cmp-map :app/scheduler)
                     (ui/cmp-map :app/ui-cmp)}
        components (make-observable components)]
    (sb/send-mult-cmd
      switchboard
      [[:cmd/init-comp components]

       [:cmd/route {:from :app/ui-cmp
                    :to   #{:app/store
                            :app/scheduler}}]

       [:cmd/observe-state {:from :app/store
                            :to   :app/ui-cmp}]

       [:cmd/route {:from :app/healthkit
                    :to   :app/store}]

       [:cmd/route {:from :app/ui-cmp
                    :to   :app/healthkit}]

       [:cmd/route {:from #{:app/store
                            :app/ui-cmp}
                    :to   :app/sync}]

       [:cmd/route {:from :app/sync
                    :to   #{:app/store
                            :app/scheduler}}]

       #_[:cmd/route {:from :app/ui-cmp
                      :to   :app/photos}]
       #_(when OBSERVER
           [:cmd/attach-to-firehose :app/sync])

       [:cmd/route {:from :app/scheduler
                    :to   #{:app/store
                            ;:app/sync
                            ;:app/healthkit
                            }}]

       [:cmd/send {:to  :app/scheduler
                   :msg [:cmd/schedule-new {:timeout 60000
                                            :message [:sync/fetch]
                                            :repeat  true
                                            :initial false}]}]

       [:cmd/send {:to  :app/scheduler
                   :msg [:cmd/schedule-new {:timeout (* 10 60 1000)
                                            :message [:sync/retry]
                                            :repeat  true
                                            :initial false}]}]])
    (.registerComponent
      AppRegistry "meins" #(identity ui/app-container))))
