(ns meo.jvm.files
  "This namespace takes care of persisting new entries to the log files.
  All changes to the graph data structure are appended to a daily log.
  Then later on application startup, all these state changes can be
  replayed to recreate the application state. This mechanism is inspired
  by Event Sourcing (http://martinfowler.com/eaaDev/EventSourcing.html)."
  (:require [meo.jvm.graph.add :as ga]
            [clj-uuid :as uuid]
            [clj-time.core :as time]
            [clj-time.format :as tf]
            [clojure.tools.logging :as log]
            [matthiasn.systems-toolbox.component :as st]
            [me.raynes.fs :as fs]
            [clojure.java.io :as io]
            [taoensso.nippy :as nippy]
            [clojure.pprint :as pp]
            [meo.jvm.file-utils :as fu]
            [ubergraph.core :as uc]
            [meo.common.utils.vclock :as vc]
            [meo.common.utils.misc :as u])
  (:import [java.io DataInputStream DataOutputStream]))

(defn filter-by-name
  "Filter a sequence of files by their name, matched via regular expression."
  [file-s regexp]
  (filter (fn [f] (re-matches regexp (.getName f))) file-s))

(defn append-daily-log
  "Appends journal entry to the current day's log file."
  [cfg entry]
  (let [filename (str (:daily-logs-path (fu/paths))
                      (tf/unparse (tf/formatters :year-month-day) (time/now))
                      ".jrn")
        serialized (str (pr-str entry) "\n")]
    (spit filename serialized :append true)))

(defn entry-import-fn
  "Handler function for persisting an imported journal entry."
  [{:keys [current-state msg-payload]}]
  (let [id (or (:id msg-payload) (uuid/v1))
        entry (merge msg-payload {:last-saved (st/now) :id id})
        ts (:timestamp entry)
        graph (:graph current-state)
        exists? (uc/has-node? graph ts)
        existing (when exists? (uc/attrs graph ts))
        node-to-add (if exists?
                      (if (= (:md existing) "No departure recorded #visit")
                        entry
                        (merge existing
                               (select-keys msg-payload [:longitude
                                                         :latitude
                                                         :horizontal-accuracy
                                                         :gps-timestamp
                                                         :linked-entries])))
                      entry)
        cfg (:cfg current-state)]
    (when-not (= existing node-to-add)
      (append-daily-log cfg node-to-add))
    {:new-state (ga/add-node current-state node-to-add)
     :emit-msg  [[:ft/add entry]]}))

(defn persist-state! [state]
  (try
    (log/info "Persisting application state")
    (let [file-path (:app-cache (fu/paths))
          serializable (update-in state [:graph] uc/ubergraph->edn)]
      (with-open [writer (io/output-stream file-path)]
        (nippy/freeze-to-out! (DataOutputStream. writer) serializable))
      (log/info "Application state saved to" file-path))
    (catch Exception ex (log/error "Error persisting cache" ex))))

(defn state-from-file []
  (let [file-path (:app-cache (fu/paths))
        thawed (with-open [reader (io/input-stream file-path)]
                 (nippy/thaw-from-in! (DataInputStream. reader)))
        state (-> thawed
                  (update-in [:sorted-entries] #(into (sorted-set-by >) %))
                  (update-in [:graph] uc/edn->ubergraph))]
    (log/info "Application state read from" file-path)
    {:state (atom state)}))

(defn geo-entry-persist-fn
  "Handler function for persisting journal entry."
  [{:keys [current-state msg-payload msg-meta put-fn]}]
  (let [ts (:timestamp msg-payload)
        node-id (-> current-state :cfg :node-id)
        new-global-vclock (vc/next-global-vclock current-state)
        entry (u/clean-entry msg-payload)
        entry (assoc-in entry [:last-saved] (st/now))
        entry (assoc-in entry [:id] (or (:id msg-payload) (uuid/v1)))
        entry (vc/set-latest-vclock entry node-id new-global-vclock)
        g (:graph current-state)
        prev (when (uc/has-node? g ts) (uc/attrs g ts))
        new-state (ga/add-node current-state entry)
        new-state (assoc-in new-state [:global-vclock] new-global-vclock)
        broadcast-meta (merge msg-meta {:sente-uid :broadcast})]
    (when (System/getenv "CACHED_APPSTATE")
      (future (persist-state! new-state)))
    (when (not= (dissoc prev :last-saved :vclock)
                (dissoc entry :last-saved :vclock))
      (append-daily-log (:cfg current-state) entry)
      (log/info "saving" entry)
      (when-not (:silent msg-meta)
        (put-fn (with-meta [:entry/saved entry] broadcast-meta)))
      {:new-state    new-state
       :send-to-self (when-let [comment-for (:comment-for msg-payload)]
                       (with-meta [:entry/find {:timestamp comment-for}] msg-meta))
       :emit-msg     [[:ft/add entry]]})))

(defn sync-entry
  "Handler function for syncing journal entry."
  [{:keys [current-state msg-payload msg-meta put-fn]}]
  (let [ts (:timestamp msg-payload)
        entry msg-payload
        g (:graph current-state)
        prev (when (uc/has-node? g ts) (uc/attrs g ts))
        new-state (ga/add-node current-state entry)]
    (when (System/getenv "CACHED_APPSTATE")
      (future (persist-state! new-state)))
    (put-fn [:sync/next {:newer-than ts}])
    (when (not= (dissoc prev :last-saved :vclock)
                (dissoc entry :last-saved :vclock))
      (append-daily-log (:cfg current-state) entry)
      (log/info "saving" entry)
      {:new-state new-state
       :emit-msg  [:ft/add entry]})))

(defn move-attachment-to-trash [cfg entry dir k]
  (when-let [filename (k entry)]
    (let [{:keys [data-path trash-path]} (fu/paths)]
      (fs/rename (str data-path "/" dir "/" filename)
                 (str trash-path filename))
      (log/info "Moved file to trash:" filename))))

(defn trash-entry-fn [{:keys [current-state msg-payload]}]
  (let [entry-ts (:timestamp msg-payload)
        new-state (ga/remove-node current-state entry-ts)
        cfg (:cfg current-state)]
    (log/info "Entry" entry-ts "marked as deleted.")
    (append-daily-log cfg {:timestamp (:timestamp msg-payload)
                           :deleted   true})
    (move-attachment-to-trash cfg msg-payload "images" :img-file)
    (move-attachment-to-trash cfg msg-payload "audio" :audio-file)
    (move-attachment-to-trash cfg msg-payload "videos" :video-file)
    {:new-state new-state
     :emit-msg  [[:ft/remove {:timestamp entry-ts}]
                 [:search/refresh]]}))
