(ns meins.jvm.files
  "This namespace takes care of persisting new entries to the log files.
  All changes to the graph data structure are appended to a daily log.
  Then later on application startup, all these state changes can be
  replayed to recreate the application state. This mechanism is inspired
  by Event Sourcing (http://martinfowler.com/eaaDev/EventSourcing.html)."
  (:require [clj-time.core :as time]
            [clj-time.format :as tf]
            [clj-uuid :as uuid]
            [clojure.java.io :as io]
            [clojure.set :as set]
            [clojure.string :as s]
            [clojure.walk :as walk]
            [matthiasn.systems-toolbox.component :as st]
            [me.raynes.fs :as fs]
            [meins.common.utils.misc :as u]
            [meins.common.utils.vclock :as vc]
            [meins.jvm.datetime :as dt]
            [meins.jvm.file-utils :as fu]
            [meins.jvm.graph.add :as ga]
            [meins.jvm.graph.query :as gq]
            [taoensso.nippy :as nippy]
            [taoensso.timbre :refer [error info warn]]
            [ubergraph.core :as uc])
  (:import [java.io DataInputStream DataOutputStream]))

(defn filter-by-name
  "Filter a sequence of files by their name, matched via regular expression."
  [file-s regexp]
  (filter (fn [f] (re-matches regexp (.getName f))) file-s))

(defn append-daily-log
  "Appends journal entry to the current day's log file."
  [cfg entry _put-fn]
  (let [_node-id (:node-id cfg)
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
        entry (enrich-story current-state entry)
        ts (:timestamp entry)
        day (dt/ymd ts)
        adjusted-day (dt/ymd (:adjusted_ts msg-payload))
        new-state (assoc-in current-state [:stats-cache :days day] nil)
        cfg (:cfg current-state)
        existing (gq/get-entry current-state ts)
        node-to-add (if existing
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
      (put-fn [:schedule/new
               {:message [:gql/run-registered
                          {:new-args {:day_strings [day adjusted-day]}}]
                :timeout 250
                :id      :imported-entry}]))
    {:new-state (ga/add-node new-state node-to-add {:clean-tags true})
     :emit-msg  [[:ft/add entry]]}))

(defn persist-state! [{:keys [current-state]}]
  (let [ks [:sorted-entries :graph :global-vclock :vclock-map :cfg :conflict]
        relevant (select-keys current-state ks)
        w-date (assoc-in relevant [:persisted] (dt/ymd (st/now)))]
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
        node-id (:node-id cfg)
        new-global-vclock (vc/next-global-vclock current-state)
        entry (u/clean-entry msg-payload)
        prev (gq/get-entry current-state ts)
        entry (remove-nils (merge prev entry))
        entry (assoc-in entry [:last_saved] (st/now))
        entry (assoc-in entry [:id] (or (:id msg-payload) (uuid/v1)))
        entry (vc/set-latest-vclock entry node-id new-global-vclock)
        day-strings (filter identity [(dt/ymd ts)
                                      (dt/ymd (:adjusted_ts msg-payload))
                                      (dt/ymd (:adjusted_ts prev))])
        new-state (ga/add-node current-state entry {:clean-tags true})
        new-state (assoc-in new-state [:global-vclock] new-global-vclock)
        vclock-offset (get-in entry [:vclock node-id])
        new-state (assoc-in new-state [:vclock-map vclock-offset] entry)
        new-state (update-in new-state [:stats-cache :days] #(apply dissoc % day-strings))
        new-state (if (set/intersection (:perm_tags entry)
                                        #{"#custom-field-cfg"
                                          "#habit-cfg"})
                    (dissoc new-state :stats-cache)
                    new-state)
        broadcast-meta (merge {:sente-uid :broadcast} msg-meta)]
    (when (not= (dissoc prev :last_saved :vclock)
                (dissoc entry :last_saved :vclock))
      (append-daily-log cfg entry put-fn)
      (put-fn [:schedule/new {:timeout 5000
                              :message [:options/gen]
                              :id      :generate-opts}])
      (when-not (s/includes? fu/data-path "playground")
        (put-fn (with-meta [:sync/imap entry] broadcast-meta)))
      (when-not (:silent msg-meta)
        (put-fn (with-meta [:entry/saved entry] broadcast-meta))
        (put-fn [:schedule/new
                 {:message [:gql/run-registered
                            {:new-args {:day_strings day-strings}}]
                  :timeout 10
                  :id      :saved-entry}]))
      #_(put-fn [:cmd/schedule-new {:message [:state/persist]
                                    :id      :persist-state
                                    :timeout 2000}])
      {:new-state new-state
       :emit-msg  [[:ft/add entry]]})))

(defn initial-save-entry
  "Handler function for creating journal entry, saving once and
  not overwriting."
  [{:keys [current-state msg-payload] :as context}]
  (let [ts (:timestamp msg-payload)
        prev (gq/get-entry current-state ts)]
    (when-not prev (geo-entry-persist-fn context))))

(defn sync-fn
  "Handler function for syncing journal entry."
  [{:keys [current-state msg-payload put-fn]}]
  (let [ts (:timestamp msg-payload)
        entry msg-payload
        rcv-vclock (:vclock entry)
        cfg (:cfg current-state)
        prev (when-let [entry (gq/get-entry current-state ts)] (remove-nils entry))
        vclocks-compared (if prev
                           (vc/vclock-compare (:vclock prev) rcv-vclock)
                           :b>a)]
    (case vclocks-compared
      :b>a (let [new-state (ga/add-node current-state entry {:clean-tags true})
                 new-global-vclock (vc/new-global-vclock new-state entry)
                 new-state (assoc-in new-state [:global-vclock] new-global-vclock)]
             (append-daily-log cfg entry put-fn)
             (put-fn [:schedule/new {:timeout 500
                                     :message [:gql/run-registered]
                                     :id      :sync-delayed-refresh}])
             {:new-state new-state
              :emit-msg  [[:ft/add entry]]})
      :concurrent (let [with-conflict (assoc-in prev [:conflict] entry)
                        new-state (ga/add-node current-state with-conflict {:clean-tags true})]
                    (warn "conflict\n" prev "\n" entry)
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
        prev (gq/get-entry current-state ts)
        new-state (ga/add-node current-state entry {:clean-tags true})
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

(defn move-attachment-to-trash [entry dir k]
  (when-let [filename (k entry)]
    (let [{:keys [data-path trash-path]} (fu/paths)]
      (fs/rename (str data-path "/" dir "/" filename)
                 (str trash-path filename))
      (info "Moved file to trash:" filename))))

(defn trash-entry-fn [{:keys [current-state msg-payload put-fn]}]
  (let [ts (:timestamp msg-payload)
        prev (gq/get-entry current-state ts)
        new-state (ga/remove-node current-state ts)
        cfg (:cfg current-state)
        node-id (:node-id cfg)
        day-strings (filter identity [(dt/ymd ts)
                                      (dt/ymd (:adjusted_ts msg-payload))
                                      (dt/ymd (:adjusted_ts prev))])
        new-global-vclock (vc/next-global-vclock current-state)
        vclock-offset (get-in new-global-vclock [node-id])
        new-state (assoc-in new-state [:global-vclock] new-global-vclock)
        new-state (update-in new-state [:stats-cache :days] #(apply dissoc % day-strings))]
    (info "Entry" ts "marked as deleted.")
    (append-daily-log cfg {:timestamp (:timestamp msg-payload)
                           :vclock    {node-id vclock-offset}
                           :deleted   true}
                      put-fn)
    (put-fn [:schedule/new
             {:message [:gql/run-registered {:new-args {:day_strings day-strings}}]
              :timeout 10}])
    (move-attachment-to-trash msg-payload "images" :img_file)
    (move-attachment-to-trash msg-payload "audio" :audio-file)
    (move-attachment-to-trash msg-payload "videos" :video-file)
    {:new-state new-state
     :emit-msg  [:ft/remove {:timestamp ts}]}))
