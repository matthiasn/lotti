(ns meo.jvm.store
  "This namespace contains the functions necessary to instantiate the store-cmp,
   which then holds the server side application state."
  (:require [meo.jvm.files :as f]
            [taoensso.timbre :refer [info error]]
            [taoensso.timbre.profiling :refer [p profile]]
            [meo.jvm.graph.query :as gq]
            [meo.jvm.graph.add :as ga]
            [meo.jvm.learn :as tf]
            [meo.jvm.export :as e]
            [meo.common.specs]
            [progrock.core :as pr]
            [clojure.data.avl :as avl]
            [ubergraph.core :as uber]
            [meo.jvm.file-utils :as fu]
            [meo.common.utils.vclock :as vc]
            [matthiasn.systems-toolbox.component :as st]
    ;[meo.jvm.graphql :as gql]
            [meo.jvm.graphql :as gql]))

(defn process-line [parsed node-id state entries-to-index]
  (let [ts (:timestamp parsed)
        local-offset (get-in parsed [:vclock node-id])]
    (if (:deleted parsed)
      (do (swap! state ga/remove-node ts)
          (swap! entries-to-index dissoc ts))
      (do (swap! entries-to-index assoc-in [ts] parsed)
          (swap! state ga/add-node parsed)))
    (swap! state update-in [:global-vclock] vc/new-global-vclock parsed)
    (when local-offset
      (swap! state update-in [:vclock-map] assoc local-offset parsed))))

(defn read-lines []
  (let [path (:daily-logs-path (fu/paths))
        files (file-seq (clojure.java.io/file path))
        filtered (f/filter-by-name files #"\d{4}-\d{2}-\d{2}.jrn")
        all-lines (atom [])
        start (st/now)]
    (info "read entry log files")
    (doseq [f (sort-by #(.getName %) filtered)]
      (with-open [reader (clojure.java.io/reader f)]
        (let [lines (line-seq reader)]
          (doseq [line lines]
            (swap! all-lines conj line)))))
    (info (count @all-lines) "lines read in" (- (st/now) start) "ms")
    @all-lines))

(defn parse-line [s]
  (try
    (clojure.edn/read-string s)
    (catch Exception ex
      (error "Exception" ex "when parsing line:\n" s))))

(defn parse-lines [lines]
  (let [start (st/now)
        parsed-lines (vec (filter identity (pmap parse-line lines)))]
    (info (count parsed-lines) "lines parsed in" (- (st/now) start) "ms")
    parsed-lines))

(defn ft-index [entries-to-index put-fn]
  (let [path (:clucy-path (fu/paths))
        files (file-seq (clojure.java.io/file path))
        clucy-dir-empty? (empty? (filter #(.isFile %) files))]
    (when clucy-dir-empty?
      (future
        (Thread/sleep 2000)
        (info "Fulltext-Indexing started")
        (let [t (with-out-str
                  (time (doseq [entry (vals @entries-to-index)]
                          (put-fn [:ft/add entry]))))]
          (info "Indexed" (count @entries-to-index) "entries." t))
        (reset! entries-to-index [])))))

(defn read-entries [{:keys [cmp-state put-fn]}]
  (let [lines (read-lines)
        parsed-lines (parse-lines lines)
        cnt (count parsed-lines)
        indexed (vec (map-indexed (fn [idx v] [idx v]) parsed-lines))
        node-id (-> @cmp-state :cfg :node-id)
        entries (atom (avl/sorted-map))
        start (st/now)
        broadcast #(put-fn (with-meta % {:sente-uid :broadcast}))
        entries-to-index (atom {})
        bar (pr/progress-bar cnt)]
    (doseq [[idx parsed] indexed]
      (let [ts (:timestamp parsed)
            progress (double (/ idx cnt))]
        (process-line parsed node-id cmp-state entries-to-index)
        (swap! cmp-state assoc-in [:startup-progress] progress)
        (when (zero? (mod idx 5000))
          (pr/print (pr/tick bar idx))
          (broadcast [:startup/progress progress]))
        (if (:deleted parsed)
          (swap! entries dissoc ts)
          (swap! entries update-in [ts] conj parsed))))
    (println)
    (info (count @entries-to-index) "entries added in" (- (st/now) start) "ms")
    (swap! cmp-state assoc-in [:startup-progress] 1)
    (broadcast [:startup/progress 1])
    (tf/import-predictions cmp-state)
    (put-fn [:cmd/schedule-new {:timeout (* 60 1000)
                                :message [:import/git]
                                :repeat  true
                                :initial false}])
    (ft-index entries-to-index put-fn)
    {}))

(defn refresh-cfg
  "Refresh configuration by reloading the config file."
  [{:keys [current-state put-fn]}]
  (let [cfg (fu/load-cfg)]
    (put-fn [:backend-cfg/new cfg])
    {:new-state (assoc-in current-state [:cfg] cfg)}))

(defn sync-done [{:keys [put-fn]}]
  (put-fn (with-meta [:search/refresh] {:sente-uid :broadcast}))
  {:send-to-self [:sync/initiate 0]})

(defn sync-send [{:keys [current-state msg-payload put-fn]}]
  {})

(defn make-state []
  (atom {:sorted-entries (sorted-set-by >)
         :graph          (uber/graph)
         :global-vclock  {}
         :vclock-map     (avl/sorted-map)
         :cfg            (fu/load-cfg)}))

(defonce state (make-state))

(defn state-fn [_put-fn]
  {:state state})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    (partial gql/state-fn state)
   :opts        {:msgs-on-firehose true
                 :in-chan          [:buffer 100]
                 :out-chan         [:buffer 100]}
   :handler-map {:entry/import      f/entry-import-fn
                 :entry/unlink      ga/unlink
                 :entry/update      f/geo-entry-persist-fn
                 :entry/sync        f/sync-fn
                 :startup/read      read-entries
                 :sync/entry        f/sync-receive
                 :sync/done         sync-done
                 :sync/initiate     sync-send
                 :sync/next         sync-send
                 :export/geojson    e/export-geojson
                 :tf/learn-stories  tf/learn-stories
                 :entry/trash       f/trash-entry-fn
                 :startup/progress? gq/query-fn
                 :cfg/refresh       refresh-cfg
                 :backend-cfg/save  fu/write-cfg
                 :gql/query          gql/run-query
                 :gql/run-registered gql/run-registered}})
