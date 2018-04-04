(ns meo.jvm.store
  "This namespace contains the functions necessary to instantiate the store-cmp,
   which then holds the server side application state."
  (:require [meo.jvm.files :as f]
            [taoensso.timbre :refer [info error]]
            [taoensso.timbre.profiling :refer [p profile]]
            [meo.jvm.graph.query :as gq]
            [meo.jvm.graph.stats :as gs]
            [meo.jvm.graph.add :as ga]
            [meo.jvm.graph.geo :as geo]
            [meo.jvm.export :as e]
            [meo.common.specs]
            [clojure.data.avl :as avl]
            [ubergraph.core :as uber]
            [meo.jvm.file-utils :as fu]
            [meo.common.utils.vclock :as vc]
            [matthiasn.systems-toolbox.component :as st]))

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
        entries-to-index (atom {})]
    (doseq [[idx parsed] indexed]
      (let [ts (:timestamp parsed)
            progress (double (/ idx cnt))]
        (process-line parsed node-id cmp-state entries-to-index)
        (swap! cmp-state assoc-in [:startup-progress] progress)
        (when (zero? (mod idx 1000))
          (broadcast [:startup/progress progress]))
        (if (:deleted parsed)
          (swap! entries dissoc ts)
          (swap! entries update-in [ts] conj parsed))))
    (info (count @entries-to-index) "entries added in" (- (st/now) start) "ms")
    (swap! cmp-state assoc-in [:startup-progress] 1)
    (broadcast [:startup/progress 1])
    (broadcast [:search/refresh])
    (ft-index entries-to-index put-fn)
    {}))

(defn state-fn
  "Creates state atom and then parses all files in data directory into the
   component state.
   Entries are stored as attributes of graph nodes, where the node itself is
   timestamp of an entry. A sort order by descending timestamp is maintained
   in a sorted set of the nodes timestamps."
  [_put-fn]
  (let [conf (fu/load-cfg)
        state (atom {:sorted-entries (sorted-set-by >)
                     :graph          (uber/graph)
                     :global-vclock  {}
                     :vclock-map     (avl/sorted-map)
                     :cfg            conf})]
    {:state state}))

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

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :opts        {:msgs-on-firehose true}
   :handler-map (merge
                  gs/stats-handler-map
                  {:entry/import     f/entry-import-fn
                   :entry/find       gq/find-entry
                   :entry/unlink     ga/unlink
                   :entry/update     f/geo-entry-persist-fn
                   :entry/sync       f/sync-fn
                   :startup/read     read-entries
                   :sync/entry       f/sync-receive
                   :sync/done        sync-done
                   :sync/initiate    sync-send
                   :sync/next        sync-send
                   :export/geojson   e/export-geojson
                   :entry/trash      f/trash-entry-fn
                   :state/search     gq/query-fn
                   :search/geo-photo geo/photos-within-bounds
                   :cfg/refresh      refresh-cfg
                   :backend-cfg/save fu/write-cfg})})
