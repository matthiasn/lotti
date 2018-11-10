(ns meo.electron.renderer.client-store
  (:require #?(:cljs [reagent.core :refer [atom]])
            #?(:clj  [taoensso.timbre :refer [info debug]]
               :cljs [taoensso.timbre :refer-macros [info debug]])
            [matthiasn.systems-toolbox.component :as st]
            [meo.electron.renderer.client-store-entry :as cse]
            [meo.electron.renderer.client-store-search :as s]
            [meo.electron.renderer.client-store-cfg :as c]
            [meo.common.utils.misc :as u]
            [meo.electron.renderer.graphql :as gql]))

(defn initial-state-fn [put-fn]
  (let [cfg (assoc-in @c/app-cfg [:qr-code] false)
        state (atom {:entries          []
                     :startup-progress 0
                     :last-alive       (st/now)
                     :busy-color       :green
                     :new-entries      @cse/new-entries-ls
                     :query-cfg        @s/query-cfg
                     :pomodoro-stats   (sorted-map)
                     :task-stats       (sorted-map)
                     :wordcount-stats  (sorted-map)
                     :gql-res2         {:left  (sorted-map-by >)
                                        :right (sorted-map-by >)}
                     :options          {:pvt-hashtags #{"#pvt"}}
                     :cfg              cfg})]
    (put-fn [:imap/get-cfg])
    {:state state}))

(defn initial-queries [{:keys [current-state put-fn] :as m}]
  (info "performing initial queries")
  (let [run-query (fn [file id prio args]
                    (put-fn [:gql/query {:file     file
                                         :id       id
                                         :res-hash nil
                                         :prio     prio
                                         :args     args}]))
        pvt (-> current-state :cfg :show-pvt)]
    (put-fn [:cfg/refresh])
    (when-let [ymd (get-in current-state [:cfg :cal-day])]
      (run-query "briefing.gql" :briefing 12 [ymd pvt])
      (run-query "logged-by-day.gql" :logged-by-day 13 [ymd])
      (put-fn [:gql/query {:file "habits-success.gql"
                           :id   :habits-success
                           :prio 13
                           :args [28 pvt]}]))
    (run-query "started-tasks.gql" :started-tasks 14 [pvt false])
    (run-query "award-points.gql" :award-points 14 [])
    (run-query "open-tasks.gql" :open-tasks 14 [pvt])
    (run-query "options.gql" :options 10 nil)
    (run-query "day-stats.gql" :day-stats 15 [90])
    (s/gql-query :left current-state false put-fn)
    (s/gql-query :right current-state false put-fn)
    (run-query "count-stats.gql" :count-stats 20 nil)
    (put-fn [:startup/progress?])
    {}))

(defn nav-handler [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:current-page] msg-payload)]
    {:new-state new-state}))

(defn blink-busy [{:keys [current-state msg-payload]}]
  (let [color (:color msg-payload)
        new-state (assoc-in current-state [:busy-status :color] color)]
    {:new-state new-state}))

(defn save-backend-cfg [{:keys [current-state msg-payload]}]
  (let [new-state (-> (assoc-in current-state [:backend-cfg] msg-payload)
                      (assoc-in [:options :custom-fields] (:custom-fields msg-payload))
                      (assoc-in [:options :questionnaires] (:questionnaires msg-payload))
                      (assoc-in [:options :custom-field-charts] (:custom-field-charts msg-payload)))]
    {:new-state new-state}))

(defn progress [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:startup-progress] msg-payload)]
    {:new-state new-state}))

(defn gql-res [{:keys [current-state msg-payload]}]
  (let [{:keys [id]} msg-payload
        new-state (assoc-in current-state [:gql-res id] msg-payload)]
    {:new-state new-state}))

(defn gql-res2 [{:keys [current-state msg-payload]}]
  (let [{:keys [tab res del incremental]} msg-payload
        prev (if incremental (get-in current-state [:gql-res2 tab]) (sorted-map-by >))
        cleaned (apply dissoc prev del)
        res-map (into cleaned (map (fn [entry] [(:timestamp entry) entry]) res))
        new-state (assoc-in current-state [:gql-res2 tab] res-map)]
    {:new-state new-state}))

(defn imap-status [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:imap-status] msg-payload)]
    {:new-state new-state}))

(defn imap-cfg [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:imap-cfg] msg-payload)]
    {:new-state new-state}))

(defn ping [_]
  #?(:cljs (info :ping))
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    initial-state-fn
   :state-spec  :state/client-store-spec
   :opts        {:in-chan        [:buffer 100]
                 :out-chan       [:buffer 100]
                 :validate-state false}
   :handler-map (merge cse/entry-handler-map
                       s/search-handler-map
                       {:cfg/save         c/save-cfg
                        :gql/res          gql-res
                        :gql/res2         gql-res2
                        :startup/progress progress
                        :startup/query    initial-queries
                        :ws/ping          ping
                        :backend-cfg/new  save-backend-cfg
                        :nav/to           nav-handler
                        :blink/busy       blink-busy
                        :imap/status      imap-status
                        :imap/cfg         imap-cfg
                        :cfg/show-qr      c/show-qr-code
                        :cal/to-day       c/cal-to-day
                        :cmd/toggle       c/toggle-set-fn
                        :cmd/set-opt      c/set-conj-fn
                        :cmd/set-dragged  c/set-currently-dragged
                        :cmd/toggle-key   c/toggle-key-fn
                        :cmd/assoc-in     c/assoc-in-state})})
