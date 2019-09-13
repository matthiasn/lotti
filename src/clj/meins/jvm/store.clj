(ns meins.jvm.store
  "This namespace contains the functions necessary to instantiate the store-cmp,
   which then holds the server side application state."
  (:require [meins.jvm.files :as f]
            [taoensso.timbre :refer [info error warn]]
            [taoensso.timbre.profiling :refer [p profile]]
            [meins.jvm.graph.query :as gq]
            [meins.jvm.graph.add :as ga]
            [meins.jvm.learn :as tf]
            [meins.jvm.metrics :as m]
            [meins.jvm.export :as e]
            [meins.jvm.store.startup :as startup]
            [meins.jvm.store.cfg :as cfg]
            [meins.common.specs]
            [clojure.data.avl :as avl]
            [ubergraph.core :as uber]
            [meins.jvm.file-utils :as fu]
            [meins.jvm.graphql :as gql]
            [meins.jvm.graphql.opts :as opts]
            [meins.jvm.graphql.exec :as exec]))

(defn sync-done [{:keys [put-fn]}]
  (put-fn (with-meta [:search/refresh] {:sente-uid :broadcast}))
  {:send-to-self [:sync/initiate 0]})

(defn make-state []
  (atom {:sorted-entries (sorted-set-by >)
         :graph          (uber/graph)
         :global-vclock  {}
         :vclock-map     (avl/sorted-map)
         :cfg            (fu/load-cfg)}))

(defonce state (make-state))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    (partial gql/state-fn state)
   :opts        {:msgs-on-firehose true
                 :in-chan          [:buffer 100]
                 :out-chan         [:buffer 100]
                 :validate-out     false}
   :handler-map {:entry/import       f/entry-import-fn
                 :entry/unlink       ga/unlink
                 :entry/update       f/geo-entry-persist-fn
                 :entry/sync         f/sync-fn
                 :options/gen        opts/gen-options
                 :startup/read       startup/read-entries
                 :sync/entry         f/sync-receive
                 :sync/done          sync-done
                 :export/geojson     e/export-geojson
                 :tf/learn-stories   tf/learn-stories
                 :entry/trash        f/trash-entry-fn
                 :startup/progress?  gq/query-fn
                 :state/persist      f/persist-state!
                 :cfg/refresh        cfg/refresh-cfg
                 :backend-cfg/save   fu/write-cfg
                 :search/remove      gql/search-remove
                 :gql/remove         gql/query-remove
                 :metrics/get        m/get-metrics
                 :gql/query          exec/run-query
                 :gql/cmd            gql/start-stop
                 :gql/run-registered gql/run-registered}})
