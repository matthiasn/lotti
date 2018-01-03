(ns meo.jvm.store
  "This namespace contains the functions necessary to instantiate the store-cmp,
   which then holds the server side application state."
  (:require [meo.jvm.files :as f]
            [taoensso.timbre.profiling :refer [p profile]]
            [meo.jvm.graph.query :as gq]
            [meo.jvm.graph.stats :as gs]
            [meo.jvm.graph.add :as ga]
            [meo.common.specs]
            [ubergraph.core :as uber]
            [matthiasn.systems-toolbox.component.helpers :as sth]
            [clojure.tools.logging :as log]
            [me.raynes.fs :as fs]
            [meo.jvm.file-utils :as fu]
            [meo.jvm.net :as net]))

(defn read-dir [state entries-to-index put-fn]
  (let [path (:daily-logs-path (fu/paths))
        files (file-seq (clojure.java.io/file path))
        filtered (f/filter-by-name files #"\d{4}-\d{2}-\d{2}.jrn")]
    (doseq [f (sort-by #(.getName %) filtered)]
      (with-open [reader (clojure.java.io/reader f)]
        (let [lines (line-seq reader)]
          (doseq [line lines]
            (try
              (let [parsed (clojure.edn/read-string line)
                    ts (:timestamp parsed)
                    cnt (count @entries-to-index)]
                (if (:deleted parsed)
                  (do (swap! state ga/remove-node ts)
                      (swap! entries-to-index dissoc ts))
                  (do (swap! entries-to-index assoc-in [ts] parsed)
                      (swap! state ga/add-node parsed)))
                (swap! state assoc-in [:latest-vclock] (:vclock parsed))
                (when (zero? (mod cnt 1000))
                  (put-fn (with-meta [:search/refresh] {:sente-uid :broadcast})))
                (when (zero? (mod cnt 5000))
                  (log/info "Entries read:" cnt)))
              (catch Exception ex
                (log/error "Exception" ex "when parsing line:\n" line)))))))
    (put-fn (with-meta [:search/refresh] {:sente-uid :broadcast}))))

(defn ft-index [entries-to-index put-fn]
  (let [path (:clucy-path (fu/paths))
        files (file-seq (clojure.java.io/file path))
        clucy-dir-empty? (empty? (filter #(.isFile %) files))]
    (when clucy-dir-empty?
      (future
        (Thread/sleep 2000)
        (log/info "Fulltext-Indexing started")
        (let [t (with-out-str
                  (time (doseq [entry (vals @entries-to-index)]
                          (put-fn [:ft/add entry]))))]
          (log/info "Indexed" (count @entries-to-index) "entries." t))
        (reset! entries-to-index [])))))

(defn recreate-state
  "Creates state atom and then parses all files in data directory into the
   component state.
   Entries are stored as attributes of graph nodes, where the node itself is
   timestamp of an entry. A sort order by descending timestamp is maintained
   in a sorted set of the nodes timestamps."
  [put-fn bg]
  (let [conf (fu/load-cfg)
        entries-to-index (atom {})
        state (atom {:sorted-entries (sorted-set-by >)
                     :graph          (uber/graph)
                     :host-id        (or (net/mac-address) (sth/make-uuid))
                     :cfg            conf})]
    (if bg
      (future
        (let [t (with-out-str (time (read-dir state entries-to-index put-fn)))]
          (log/info "Read" (count @entries-to-index) "entries." t)
          (ft-index entries-to-index put-fn)))
      (let [t (with-out-str (time (read-dir state entries-to-index put-fn)))]
        (log/info "Read" (count @entries-to-index) "entries." t)
        (ft-index entries-to-index put-fn)))
    {:state state}))

(defn state-fn
  "Initial state function. If persisted state exists, read that (much faster),
   otherwise recreate it from then append log. Should be deleted or renamed
   whenever there is an application update to avoid inconsistencies."
  [bg]
  (fn [put-fn]
    (try
      (if (and (System/getenv "CACHED_APPSTATE")
               (fs/exists? (:app-cache (fu/paths))))
        (f/state-from-file)
        (recreate-state put-fn bg))
      (catch Exception ex (do (log/error "Error reading cache" ex)
                              (recreate-state put-fn bg))))))

(defn refresh-cfg
  "Refresh configuration by reloading the config file."
  [{:keys [current-state]}]
  {:new-state (assoc-in current-state [:cfg] (fu/load-cfg))})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    (state-fn true)
   :opts        {:msgs-on-firehose true}
   :handler-map (merge
                  gs/stats-handler-map
                  {:entry/import f/entry-import-fn
                   :entry/find   gq/find-entry
                   :entry/unlink ga/unlink
                   :entry/update f/geo-entry-persist-fn
                   :sync/entry   f/sync-entry
                   :entry/trash  f/trash-entry-fn
                   :state/search gq/query-fn
                   :cfg/refresh  refresh-cfg})})
