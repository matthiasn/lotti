(ns meins.jvm.files
  "This namespace takes care of persisting new entries to the log files.
  All changes to the graph data structure are appended to a daily log.
  Then later on application startup, all these state changes can be
  replayed to recreate the application state. This mechanism is inspired
  by Event Sourcing (http://martinfowler.com/eaaDev/EventSourcing.html)."
  (:require [meins.jvm.graph.add :as ga]
            [clj-uuid :as uuid]
            [clj-time.core :as time]
            [clj-time.format :as tf]
            [taoensso.timbre :refer [info error warn]]
            [matthiasn.systems-toolbox.component :as st]
            [me.raynes.fs :as fs]
            [clojure.java.io :as io]
            [taoensso.nippy :as nippy]
            [meins.jvm.file-utils :as fu]
            [buddy.core.hash :as hash]
            [buddy.core.codecs.base64 :as b64]
            [buddy.sign.jwe :as jwe]
            [buddy.core.nonce :as nonce]
            [ubergraph.core :as uc]
            [meins.common.utils.vclock :as vc]
            [meins.common.utils.misc :as u]
            [meins.jvm.graph.query :as gq]
            [clojure.walk :as walk]
            [meins.jvm.datetime :as dt]
            [clojure.string :as s])
  (:import [java.io DataInputStream DataOutputStream]))

(defn filter-by-name
  "Filter a sequence of files by their name, matched via regular expression."
  [file-s regexp]
  (filter (fn [f] (re-matches regexp (.getName f))) file-s))

(defn append-daily-log
  "Appends journal entry to the current day's log file."
  [cfg entry put-fn]
  (let [node-id (:node-id cfg)
        filename (str (tf/unparse (tf/formatters :year-month-day) (time/now))
                      ".jrn")
        full-path (str (:daily-logs-path (fu/paths))
                       filename)
        serialized (str (pr-str entry) "\n")]
    (spit full-path serialized :append true)
    #_(put-fn [:file/encrypt {:filename filename
                              :node-id  node-id}])))
(defn enrich-story [state entry]
  (let [custom-fields (get-in state [:options :custom_fields])
        tag (or (first (:perm_tags entry))
                (first (:tags entry)))
        story (get-in custom-fields [tag :primary_story])]
    (assoc entry :linked-story story)))

(defn entry-import-fn
  "Handler function for persisting an imported journal entry."
  [{:keys [current-state msg-payload put-fn msg-meta]}]
  (let [id (or (:id msg-payload) (uuid/v1))
        entry (merge msg-payload {:last_saved (st/now) :id id})
        entry  (enrich-story current-state entry)
        ts (:timestamp entry)
        graph (:graph current-state)
        cfg (:cfg current-state)
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
        broadcast-meta (merge {:sente-uid :broadcast} msg-meta)]
    (when-not (= existing node-to-add)
      (append-daily-log cfg node-to-add put-fn)
      (put-fn (with-meta [:entry/saved entry] broadcast-meta))
      (put-fn [:cmd/schedule-new
               {:message [:gql/run-registered]
                :timeout 250
                :id      :imported-entry}]))

    {:new-state (ga/add-node current-state node-to-add)
     :emit-msg  [[:ft/add entry]]}))

(defn persist-state! [{:keys [current-state]}]
  (let [ks [:sorted-entries :graph :global-vclock :vclock-map :cfg :conflict]
        relevant (select-keys current-state ks)
        w-date (assoc-in relevant [:persisted] (dt/ts-to-ymd (st/now)))]
    (try
      (info "Persisting application state as Nippy file")
      (let [file-path (:app-cache (fu/paths))
            serializable (update-in w-date [:graph] uc/ubergraph->edn)]
        (with-open [writer (io/output-stream file-path)]
          (nippy/freeze-to-out! (DataOutputStream. writer) serializable))
        (info "Application state saved to nippy file" file-path (count (:sorted-entries relevant))))
      (catch Exception ex (error "Error persisting cache" ex)))
    {}))

(defn state-from-file []
  (try
    (info "reading cached state")
    (let [file-path (:app-cache (fu/paths))
          thawed (with-open [reader (io/input-stream file-path)]
                   (nippy/thaw-from-in! (DataInputStream. reader)))
          state (-> thawed
                    (update-in [:sorted-entries] #(into (sorted-set-by >) %))
                    (update-in [:graph] uc/edn->ubergraph))
          n (count (:sorted-entries state))]
      (info "Application state read from" file-path "-" n "entries")
      (atom state))
    (catch Exception ex (error ex))))

;; from https://stackoverflow.com/a/34221816
(defn remove-nils [m]
  (let [f (fn [x]
            (if (map? x)
              (let [kvs (filter (comp not nil? second) x)]
                (if (empty? kvs) nil (into {} kvs)))
              x))]
    (walk/postwalk f m)))

(defn geo-entry-persist-fn
  "Handler function for persisting journal entry."
  [{:keys [current-state msg-payload msg-meta put-fn]}]
  (let [ts (:timestamp msg-payload)
        cfg (:cfg current-state)
        g (:graph current-state)
        node-id (:node-id cfg)
        new-global-vclock (vc/next-global-vclock current-state)
        entry (u/clean-entry msg-payload)
        prev (when (uc/has-node? g ts) (uc/attrs g ts))
        entry (remove-nils (merge prev entry))
        entry (assoc-in entry [:last_saved] (st/now))
        entry (assoc-in entry [:id] (or (:id msg-payload) (uuid/v1)))
        entry (vc/set-latest-vclock entry node-id new-global-vclock)
        new-state (ga/add-node current-state entry)
        new-state (assoc-in new-state [:global-vclock] new-global-vclock)
        vclock-offset (get-in entry [:vclock node-id])
        new-state (assoc-in new-state [:vclock-map vclock-offset] entry)
        broadcast-meta (merge {:sente-uid :broadcast} msg-meta)]
    (when (not= (dissoc prev :last_saved :vclock)
                (dissoc entry :last_saved :vclock))
      (append-daily-log cfg entry put-fn)
      (put-fn [:cmd/schedule-new {:timeout 5000
                                  :message [:options/gen]
                                  :id      :generate-opts}])
      #_(put-fn [:cmd/schedule-new {:timeout (* 60 60 1000)
                                    :message [:state/persist]
                                    :id      :persist-state}])
      (when-not (s/includes? fu/data-path "playground")
        (put-fn (with-meta [:sync/imap entry] broadcast-meta)))
      (when-not (:silent msg-meta)
        (put-fn (with-meta [:entry/saved entry] broadcast-meta))
        (put-fn [:cmd/schedule-new {:message [:gql/run-registered]
                                    :timeout 10
                                    :id      :saved-entry}]))
      {:new-state new-state
       :emit-msg  [[:ft/add entry]]})))

(defn sync-fn
  "Handler function for syncing journal entry."
  [{:keys [current-state msg-payload msg-meta put-fn]}]
  (let [ts (:timestamp msg-payload)
        entry msg-payload
        rcv-vclock (:vclock entry)
        cfg (:cfg current-state)
        g (:graph current-state)
        prev (when (uc/has-node? g ts) (remove-nils (uc/attrs g ts)))
        new-meta (update-in msg-meta [:cmp-seq] #(vec (take-last 10 %)))
        vclocks-compared (if prev
                           (vc/vclock-compare (:vclock prev) rcv-vclock)
                           :b>a)]
    (info "sync-fn" vclocks-compared)
    (case vclocks-compared
      :b>a (let [new-state (ga/add-node current-state entry)]
             ;(put-fn (with-meta [:entry/saved entry] broadcast-meta))
             (append-daily-log cfg entry put-fn)
             {:new-state new-state
              :emit-msg  [[:cmd/schedule-new {:timeout 2500
                                              :message (with-meta [:gql/run-registered] {:sente-uid :broadcast})
                                              :id      :sync-delayed-refresh}]
                          [:ft/add entry]]})
      :concurrent (let [with-conflict (assoc-in prev [:conflict] entry)
                        new-state (ga/add-node current-state with-conflict)]
                    (warn "conflict\n" prev "\n" entry)
                    ;(put-fn (with-meta [:entry/saved entry] broadcast-meta))
                    (append-daily-log cfg entry put-fn)
                    {:new-state new-state
                     :emit-msg  [:ft/add entry]})
      {})))

(defn sync-receive
  "Handler function for syncing journal entry."
  [{:keys [current-state msg-payload msg-meta put-fn]}]
  (let [ts (:timestamp msg-payload)
        entry msg-payload
        received-vclock (:vclock entry)
        cfg (:cfg current-state)
        g (:graph current-state)
        prev (when (uc/has-node? g ts) (uc/attrs g ts))
        new-state (ga/add-node current-state entry)
        new-meta (update-in msg-meta [:cmp-seq] #(vec (take-last 10 %)))
        broadcast-meta (merge new-meta {:sente-uid :broadcast})
        vclocks-compared (when prev
                           (vc/vclock-compare (:vclock prev) received-vclock))]
    (info vclocks-compared)
    (put-fn (with-meta [:sync/next {:newer-than    ts
                                    :newer-than-vc received-vclock}] new-meta))
    (when (= vclocks-compared :concurrent)
      (warn "conflict:" prev entry))
    (when-not (contains? #{:a>b :concurrent :equal} vclocks-compared)
      (when (= :b>a vclocks-compared)
        (put-fn (with-meta [:entry/saved entry] broadcast-meta)))
      (append-daily-log cfg entry put-fn)
      {:new-state new-state
       :emit-msg  [:ft/add entry]})))

(defn move-attachment-to-trash [cfg entry dir k]
  (when-let [filename (k entry)]
    (let [{:keys [data-path trash-path]} (fu/paths)]
      (fs/rename (str data-path "/" dir "/" filename)
                 (str trash-path filename))
      (info "Moved file to trash:" filename))))

(defn trash-entry-fn [{:keys [current-state msg-payload put-fn]}]
  (let [entry-ts (:timestamp msg-payload)
        new-state (ga/remove-node current-state entry-ts)
        cfg (:cfg current-state)
        node-id (:node-id cfg)
        new-global-vclock (vc/next-global-vclock current-state)
        vclock-offset (get-in new-global-vclock [node-id])
        new-state (assoc-in new-state [:global-vclock] new-global-vclock)]
    (info "Entry" entry-ts "marked as deleted.")
    (append-daily-log cfg {:timestamp (:timestamp msg-payload)
                           :vclock    {node-id vclock-offset}
                           :deleted   true}
                      put-fn)
    (put-fn [:cmd/schedule-new {:message [:gql/run-registered]
                                :timeout 10}])
    (move-attachment-to-trash cfg msg-payload "images" :img_file)
    (move-attachment-to-trash cfg msg-payload "audio" :audio-file)
    (move-attachment-to-trash cfg msg-payload "videos" :video-file)
    {:new-state new-state
     :emit-msg  [:ft/remove {:timestamp entry-ts}]}))
