(ns meins.jvm.store.startup
  "This namespace contains the functions necessary to instantiate the store-cmp."
  (:require [clojure.edn :as edn]
            [clojure.java.io :as io]
            [clojure.spec.alpha :as s]
            [clojure.string :as str]
            [expound.alpha :as exp]
            [matthiasn.systems-toolbox.component :as st]
            [meins.common.specs]
            [meins.common.utils.vclock :as vc]
            [meins.jvm.file-utils :as fu]
            [meins.jvm.files :as f]
            [meins.jvm.graph.add :as ga]
            [meins.jvm.graphql.opts :as opts]
            [progrock.core :as pr]
            [taoensso.timbre :refer [error info warn]]))

(defn process-line [parsed node-id state entries-to-index]
  (let [ts (:timestamp parsed)
        local-offset (get-in parsed [:vclock node-id])]
    (if (s/valid? :meins.entry/spec parsed)
      (do (if (:deleted parsed)
            (swap! entries-to-index dissoc ts)
            (swap! entries-to-index update-in [ts] merge parsed))
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
    (doseq [f sorted]
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

(defn progress-update [idx cnt]
  (let [x (Math/floor (/ cnt 100))]
    (and (pos? x)
         (zero? (mod idx x)))))

(defn add-to-graph [cmp-state entries-to-index broadcast]
  (let [cnt (count @entries-to-index)
        bar (pr/progress-bar cnt)
        start (st/now)]
    (doseq [[idx [_ts entry]] (map-indexed (fn [idx v] [idx v]) @entries-to-index)]
      (let [progress (double (/ idx cnt))]
        (swap! cmp-state ga/add-node entry {})
        (when (progress-update idx cnt)
          (pr/print (pr/tick bar idx))
          (swap! cmp-state assoc-in [:startup-progress :graph] progress)
          (broadcast [:startup/progress {:graph progress}]))))
    (println)
    (info (count @entries-to-index) "entries added to Graph in" (- (st/now) start) "ms")
    (broadcast [:startup/progress {:graph 1}])
    (swap! cmp-state assoc-in [:startup-progress :graph] 1)))

(defn read-entries [{:keys [cmp-state put-fn]}]
  (let [lines (read-lines cmp-state)
        parsed-lines (parse-lines lines)
        cnt (count parsed-lines)
        indexed (vec (map-indexed (fn [idx v] [idx v]) parsed-lines))
        node-id (-> @cmp-state :cfg :node-id)
        start (st/now)
        broadcast #(put-fn (with-meta % {:sente-uid :broadcast}))
        entries-to-index (atom {})
        bar (pr/progress-bar cnt)]
    (doseq [[idx parsed] indexed]
      (try
        (let [progress (double (/ idx cnt))]
          (swap! cmp-state assoc-in [:startup-progress :lines] progress)
          (process-line parsed node-id cmp-state entries-to-index)
          (when (progress-update idx cnt)
            (pr/print (pr/tick bar idx))
            (broadcast [:startup/progress {:lines progress}])))
        (catch Exception ex (error "reading line" ex parsed))))
    (println)
    (info (count @entries-to-index) "entries added in" (- (st/now) start) "ms")
    (broadcast [:startup/progress {:lines 1}])
    (swap! cmp-state assoc-in [:startup-progress :lines] 1)
    (add-to-graph cmp-state entries-to-index broadcast)
    (opts/gen-options {:cmp-state cmp-state})
    (put-fn [:schedule/new {:timeout 1000
                            :message [:gql/run-registered]
                            :id      :run-registered}])
    (broadcast [:sync/start-imap])
    (put-fn [:import/git])
    (ft-index entries-to-index put-fn)
    {}))

(defn sync-done [{:keys [put-fn]}]
  (put-fn (with-meta [:search/refresh] {:sente-uid :broadcast}))
  {:send-to-self [:sync/initiate 0]})
