(ns meins.store
  (:require-macros [cljs.core.async.macros :refer [go]])
  (:require [matthiasn.systems-toolbox.component :as st]
            [meins.ui.shared :refer [alert]]
            [meins.ui.db :as uidb]
            [glittershark.core-async-storage :as as]
            ["realm" :as realm]
            [clojure.data.avl :as avl]
            [cljs.core.async :refer [<!]]
            [meins.helpers :as h]))

(defn persist [{:keys [msg-type current-state put-fn msg-payload msg-meta]}]
  (let [{:keys [timestamp vclock id]} msg-payload
        last-vclock (:global-vclock current-state)
        instance-id (str (:instance-id current-state))
        realm-db (:realm-db current-state)
        offset (inc (or (get last-vclock instance-id) 0))
        new-vclock {instance-id offset}
        id (or id (st/make-uuid))
        prev (dissoc (get-in current-state [:entries timestamp])
                     :id :last-saved :vclock)
        entry (merge prev msg-payload {:last-saved (st/now)
                                       :id         (str id)
                                       :vclock     (merge vclock new-vclock)})
        entry (h/remove-nils entry)
        new-state (-> current-state
                      (assoc-in [:entries timestamp] entry)
                      (assoc-in [:vclock-map offset] entry)
                      (assoc-in [:global-vclock] new-vclock))]
    (when realm-db
      (try
        (.write realm-db
                (fn []
                  (let [db-entry (-> entry
                                     (select-keys [:md :timestamp :longitude :latitude])
                                     (assoc :edn (pr-str entry))
                                     (assoc :sync (if (:from-sync msg-meta) "SYNC" "OPEN"))
                                     clj->js)
                        x (.create realm-db "Entry" db-entry true)])
                  (put-fn [:schedule/new {:timeout 1000
                                          :message [:sync/retry]
                                          :id      :sync}])))
        (catch :default e (js/console.error e))))
    (when-not (= prev (dissoc msg-payload :id :last-saved :vclock))
      (go (<! (as/set-item :global-vclock last-vclock)))
      {:new-state new-state})))

(defn hide [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        new-state (update-in current-state [:hide-timestamps] conj ts)]
    (go (<! (as/set-item :hide-timestamps (:hide-timestamps new-state))))
    {:new-state new-state}))

(defn detail [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:entry-detail] msg-payload)]
    {:new-state new-state}))

(defn theme [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:active-theme] msg-payload)]
    (go (<! (as/set-item :active-theme msg-payload)))
    {:new-state new-state}))

(defn current-activity [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:current-activity] msg-payload)]
    {:new-state new-state}))

(defn sync-start [{:keys [current-state msg-payload put-fn]}]
  (let [vclock-map (:vclock-map current-state)
        ;latest-synced (:latest-synced current-state)
        ;newer-than (:newer-than msg-payload latest-synced)
        instance-id (str (:instance-id current-state))
        offset (get-in msg-payload [:newer-than-vc instance-id])
        [_offset entry] (avl/nearest vclock-map > offset)
        new-state (assoc-in current-state [:latest-synced] offset)]
    (go (<! (as/set-item :latest-synced offset)))
    (if entry (put-fn [:sync/entry entry])
              (put-fn [:sync/done]))
    {:new-state new-state}))

(defn load-state [{:keys [cmp-state put-fn]}]
  (go
    (try
      (let [latest-vclock (second (<! (as/get-item :global-vclock)))]
        (put-fn [:debug/latest-vclock latest-vclock])
        (swap! cmp-state assoc-in [:global-vclock] latest-vclock))
      (catch js/Object e (js/console.error "get-global-vclock" e))))
  (go
    (try
      (let [active-theme (second (<! (as/get-item :active-theme)))]
        (swap! cmp-state assoc-in [:active-theme] (or active-theme :light)))
      (catch js/Object e (js/console.error "load-theme" e))))
  (go
    (try
      (let [secrets (second (<! (as/get-item :secrets)))]
        (when secrets
          (swap! cmp-state assoc-in [:secrets] secrets)))
      (catch js/Object e (js/console.error "load-secrets" e))))
  (go
    (try
      (let [cfg (second (<! (as/get-item :cfg)))]
        (when cfg
          (swap! cmp-state assoc-in [:cfg] cfg)))
      (catch js/Object e (js/console.error "load-cfg" e))))
  (go
    (try
      (let [latest-synced (second (<! (as/get-item :latest-synced)))]
        (put-fn [:debug/latest-synced latest-synced])
        (swap! cmp-state assoc-in [:latest-synced] latest-synced))
      (catch js/Object e (js/console.error "get-latest-synced" e))))
  (go
    (try
      (let [instance-id (str (or (second (<! (as/get-item :instance-id)))
                                 (st/make-uuid)))
            timestamps (second (<! (as/get-item :timestamps)))
            sorted (apply sorted-set timestamps)]
        (swap! cmp-state assoc-in [:instance-id] instance-id)
        (<! (as/set-item :instance-id instance-id)))
      (catch js/Object e (js/console.error "load-state" e))))
  (go
    (try
      (let [hide-timestamps (second (<! (as/get-item :hide-timestamps)))]
        (when hide-timestamps
          (swap! cmp-state assoc-in [:hide-timestamps] hide-timestamps)))
      (catch js/Object e
        (put-fn [:debug/error {:msg e}]))))
  (put-fn [:debug/state-fn-complete])
  {})

(defn state-reset [{:keys [cmp-state put-fn]}]
  (let [new-state {:entries       (avl/sorted-map)
                   :latest-synced 0}]
    (go (<! (as/clear)))
    (load-state {:cmp-state cmp-state :put-fn put-fn})
    {:new-state new-state}))

(defn set-secrets [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:secrets] msg-payload)]
    (go (<! (as/set-item :secrets msg-payload)))
    {:new-state new-state}))

(defn set-cfg [{:keys [current-state msg-payload]}]
  (let [cfg (merge (:cfg current-state) msg-payload)
        new-state (assoc-in current-state [:cfg] cfg)]
    (go (<! (as/set-item :cfg cfg)))
    {:new-state new-state}))

(def EntrySchema
  {:name       "Entry"
   :primaryKey "timestamp"
   :properties {:timestamp "int"
                :md        {:type "string" :indexed true}
                :edn       "string"
                :sync      {:type "string" :default "OPEN" :optional true}
                :latitude  {:type "float" :default 0.0 :optional true}
                :longitude {:type "float" :default 0.0 :optional true}}})

(def ImageSchema
  {:name       "Image"
   :primaryKey "timestamp"
   :properties {:timestamp "int"
                :imported  "bool"
                :fileName  "string"
                :uri       "string"
                :width     "int"
                :height    "int"
                :latitude  {:type "float" :default 0.0 :optional true}
                :longitude {:type "float" :default 0.0 :optional true}}})

(defn state-fn [put-fn]
  (let [state (atom {:entries         (avl/sorted-map)
                     :active-theme    :light
                     :hide-timestamps (sorted-set)
                     :vclock-map      (avl/sorted-map)
                     :cfg             {:sync-active  true
                                       :entry-pprint false}
                     :latest-synced   0})]
    (load-state {:cmp-state state
                 :put-fn    put-fn})
    (-> (.open realm (clj->js {:schema [EntrySchema ImageSchema]}))
        (.then (fn [db]
                 (js/console.warn "db finished opening" db)
                 (swap! state assoc :realm-db db)
                 (reset! uidb/realm-db db)
                 (js/console.warn (.-length (.objects db "Entry")) "entries")
                 (js/console.warn (.-length (.objects db "Image")) "photos")))
        (.catch (fn [err] (js/console.error "Realm: " (.-message err)))))
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:entry/persist    persist
                 :entry/new        persist
                 :entry/hide       hide
                 :entry/sync       persist
                 :entry/detail     detail
                 :sync/initiate    sync-start
                 :sync/next        sync-start
                 :state/load       load-state
                 :state/reset      state-reset
                 :secrets/set      set-secrets
                 :cfg/set          set-cfg
                 :theme/active     theme
                 :activity/current current-activity}})
