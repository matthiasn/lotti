(ns meins.jvm.store.startup
  "This namespace contains the functions necessary to instantiate the store-cmp."
  (:require [meins.jvm.files :as f]
            [taoensso.timbre :refer [info error warn]]
            [taoensso.timbre.profiling :refer [p profile]]
            [meins.jvm.graph.add :as ga]
            [meins.common.specs]
            [progrock.core :as pr]
            [clojure.data.avl :as avl]
            [meins.jvm.file-utils :as fu]
            [meins.common.utils.vclock :as vc]
            [matthiasn.systems-toolbox.component :as st]
            [clojure.spec.alpha :as s]
            [expound.alpha :as exp]
            [clojure.string :as str]
            [clojure.java.io :as io]
            [clojure.edn :as edn]
            [meins.jvm.graphql.opts :as opts]))

(defn process-line [parsed node-id state entries-to-index]
  (let [ts (:timestamp parsed)
        local-offset (get-in parsed [:vclock node-id])]
    (if (s/valid? :meins.entry/spec parsed)
      (do (if (:deleted parsed)
            (do (swap! state ga/remove-node ts)
                (swap! entries-to-index dissoc ts))
            (do (swap! entries-to-index assoc-in [ts] parsed)
                (swap! state ga/add-node parsed)))
          (swap! state update-in [:global-vclock] vc/new-global-vclock parsed)
          (when local-offset
            (swap! state update-in [:vclock-map] assoc local-offset parsed)))
      (do (warn "Invalid parsed entry:" parsed)
          (warn (exp/expound-str :meins.entry/spec parsed))))))

(defn read-lines [cmp-state]
  (let [read-from (:persisted @cmp-state)
        path (:daily-logs-path (fu/paths))
        files (file-seq (io/file path))
        filtered (f/filter-by-name files #"\d{4}-\d{2}-\d{2}.jrn")
        sorted (sort-by #(.getName %) filtered)
        newer-than (if read-from
                     (drop-while #(not (str/includes? (.getName %) read-from))
                                 sorted)
                     sorted)
        all-lines (atom [])
        start (st/now)]
    (info "reading logs" read-from (vec newer-than))
    (doseq [f newer-than]
      (with-open [reader (io/reader f)]
        (let [lines (line-seq reader)]
          (doseq [line lines]
            (swap! all-lines conj line)))))
    (info (count @all-lines) "lines read in" (- (st/now) start) "ms")
    @all-lines))

(defn parse-line [s]
  (try
    (edn/read-string s)
    (catch Exception ex
      (error "Exception" ex "when parsing line:\n" s))))

(defn parse-lines [lines]
  (let [start (st/now)
        parsed-lines (vec (filter identity (pmap parse-line lines)))]
    (info (count parsed-lines) "lines parsed in" (- (st/now) start) "ms")
    parsed-lines))

(defn ft-index [entries-to-index put-fn]
  (let [path (:clucy-path (fu/paths))
        files (file-seq (io/file path))
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
  (let [lines (read-lines cmp-state)
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
      (try
        (let [ts (:timestamp parsed)
              progress (double (/ idx cnt))]
          (swap! cmp-state assoc-in [:startup-progress] progress)
          (process-line parsed node-id cmp-state entries-to-index)
          (when (zero? (mod idx 5000))
            (pr/print (pr/tick bar idx))
            (broadcast [:startup/progress progress]))
          (if (:deleted parsed)
            (swap! entries dissoc ts)
            (swap! entries update-in [ts] conj parsed)))
        (catch Exception ex (error "reading line" ex parsed))))
    (println)
    (info (count @entries-to-index) "entries added in" (- (st/now) start) "ms")
    (swap! cmp-state assoc-in [:startup-progress] 1)
    (opts/gen-options {:cmp-state cmp-state})
    (put-fn [:cmd/schedule-new {:timeout 1000
                                :message [:gql/run-registered]
                                :id      :run-registered}])
    (broadcast [:startup/progress 1])
    (broadcast [:sync/start-imap])
    (put-fn [:import/git])
    (ft-index entries-to-index put-fn)
    {}))

(defn sync-done [{:keys [put-fn]}]
  (put-fn (with-meta [:search/refresh] {:sente-uid :broadcast}))
  {:send-to-self [:sync/initiate 0]})
