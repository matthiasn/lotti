(ns meins.electron.renderer.client-store
  (:require #?(:cljs [reagent.core :refer [atom]])
            #?(:clj  [taoensso.timbre :refer [debug info]]
               :cljs [taoensso.timbre :refer [debug info]])
            [matthiasn.systems-toolbox.component :as st]
            [meins.electron.renderer.client-store.cfg :as c]
            [meins.electron.renderer.client-store.entry :as cse]
            [meins.electron.renderer.client-store.handlers :as csh]
            [meins.electron.renderer.client-store.initial :as csi]
            [meins.electron.renderer.client-store.search :as s]))

(defn state-fn [put-fn]
  (let [cfg (assoc-in @c/app-cfg [:qr-code] false)
        state (atom {:entries          []
                     :startup-progress {}
                     :last-alive       (st/now)
                     :busy-color       :green
                     :new-entries      @cse/new-entries-ls
                     :query-cfg        @s/query-cfg
                     :pomodoro-stats   (sorted-map)
                     :task-stats       (sorted-map)
                     :wordcount-stats  (sorted-map)
                     :dashboard-data   (sorted-map)
                     :gql-res2         {:left  {:res (sorted-map-by >)}
                                        :right {:res (sorted-map-by >)}}
                     :options          {:pvt-hashtags #{"#pvt"}}
                     :cfg              cfg})]
    (put-fn [:imap/get-cfg])
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :state-spec  :state/client-store-spec
   :handler-map (merge cse/entry-handler-map
                       s/search-handler-map
                       {:cfg/save         c/save-cfg
                        :crypto/cfg       c/save-crypto
                        :gql/res          csh/gql-res
                        :gql/res2         csh/gql-res2
                        :gql/remove       csh/gql-remove
                        :startup/progress csh/progress
                        :startup/query    csi/initial-queries
                        :ws/ping          csh/ping
                        :backend-cfg/new  csh/save-backend-cfg
                        :nav/to           csh/nav-handler
                        :blink/busy       csh/blink-busy
                        :imap/status      csh/imap-status
                        :imap/cfg         csh/imap-cfg
                        :cfg/show-qr      c/show-qr-code
                        :cal/to-day       c/cal-to-day
                        :cmd/toggle       c/toggle-set-fn
                        :cmd/set-opt      c/set-conj-fn
                        :metrics/info     csh/save-metrics
                        :update/status    csh/set-updater-status
                        :cmd/set-dragged  c/set-currently-dragged
                        :cmd/toggle-key   c/toggle-key-fn
                        :cmd/assoc-in     c/assoc-in-state})})
