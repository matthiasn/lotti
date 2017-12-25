(ns meo.client-store-entry
  (:require
    [matthiasn.systems-toolbox.component :as st]
    [meo.utils.misc :as u]
    [meo.utils.parse :as p]))

(defonce new-entries-ls (atom {}))

(defn update-local-storage [state]
  (reset! new-entries-ls (:new-entries state)))

(defn toggle-set-fn [{:keys [current-state msg-payload]}]
  (let [path (:path msg-payload)
        timestamp (:timestamp msg-payload)
        new-state (if (contains? (get-in current-state path) timestamp)
                    (update-in current-state path disj timestamp)
                    (update-in current-state path conj timestamp))]
    {:new-state new-state}))

(defn toggle-key-fn [{:keys [current-state msg-payload]}]
  (let [path (:path msg-payload)]
    {:new-state (update-in current-state path not)}))

(defn new-entry-fn [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        new-state (assoc-in current-state [:new-entries ts] msg-payload)]
    (update-local-storage new-state)
    {:new-state new-state
     :emit-msg  [:entry/update msg-payload]}))

(defn geo-enrich-fn [{:keys [current-state msg-payload put-fn]}]
  (let [ts (:timestamp msg-payload)
        geo-info (select-keys msg-payload [:timestamp :latitude :longitude])
        local-entry (get-in current-state [:new-entries ts])
        new-state (update-in current-state [:new-entries ts] #(merge geo-info %))]

    (put-fn [:entry/update geo-info])

    (when-not local-entry
      (put-fn [:entry/update geo-info]))
    (when local-entry
      (update-local-storage new-state)
      {:new-state new-state})))

(defn entry-saved-fn [{:keys [current-state msg-payload msg-meta]}]
  (let [ts (:timestamp msg-payload)
        curr-local (get-in current-state [:new-entries ts])
        parent-ts (:comment-for msg-payload)
        new-state (if (= (:md curr-local) (:md msg-payload))
                    (-> current-state
                        (update-in [:new-entries] dissoc ts)
                        (assoc-in [:busy] false)
                        (assoc-in [:entries-map ts] msg-payload))
                    current-state)]
    (update-local-storage new-state)
    {:new-state    new-state
     :send-to-self (with-meta [:search/refresh] msg-meta)}))

(defn play-audio [id]
  #?(:cljs (.play (.getElementById js/document id))))

(defn pomodoro-inc-fn [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        new-state (update-in current-state [:new-entries ts :completed-time] inc)]
    (when (get-in current-state [:new-entries ts])
      (let [new-entry (get-in new-state [:new-entries ts])
            done? (= (:planned-dur new-entry) (:completed-time new-entry))
            cfg (:cfg current-state)
            new-state (-> new-state
                          (assoc-in [:busy] (not done?))
                          (assoc-in [:last-busy] (st/now)))
            new-state (if done?
                        (update-in new-state [:new-entries ts :pomodoro-running] not)
                        new-state)]
        (if (:pomodoro-running new-entry)
          (do (when-not (:mute cfg)
                (if done? (play-audio "ringer")
                          (when (:ticking-clock cfg)
                            (play-audio "ticking-clock"))))
              (update-local-storage new-state)
              {:new-state new-state
               :emit-msg  (when (not done?)
                            [[:blink/busy {:pomodoro-completed done?}]
                             [:cmd/schedule-new
                              {:timeout 1000
                               :message [:cmd/pomodoro-inc {:timestamp ts}]}]])})
          {:new-state current-state})))))

(defn pomodoro-start-fn
  "Start pomodoro for entry. Will toggle the :pomodoro-running status of the
   entry and schedule an initial increment message."
  [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        new-state (-> current-state
                      (update-in [:new-entries ts :pomodoro-running] not)
                      (assoc-in [:busy] false))]
    (when (get-in current-state [:new-entries ts])
      (update-local-storage new-state)
      {:new-state    new-state
       :send-to-self [:cmd/pomodoro-inc {:timestamp ts}]})))

(defn update-local-fn [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        saved (get-in current-state [:entries-map ts])
        relevant #(select-keys % [:md :questionnaires :custom-fields :task
                                  :habit :completed-time :starred])
        changed? (not= (relevant saved) (relevant msg-payload))]
    (if changed?
      (let [new-entry (get-in current-state [:new-entries ts])
            entry (u/deep-merge saved new-entry msg-payload)
            parsed (p/parse-entry (:md entry))
            updated (merge entry parsed)
            updated (if (-> updated :questionnaires :pomo1)
                      (update-in updated [:tags] conj "#PSS")
                      updated)
            new-state (assoc-in current-state [:new-entries ts] updated)]
        (update-local-storage new-state)
        {:new-state new-state})
      {})))

(defn update-fn [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)]
    {}))

(defn remove-local-fn [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        new-state (update-in current-state [:new-entries] dissoc ts)]
    (update-local-storage new-state)
    {:new-state new-state}))

(defn found-entry-fn [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        new-state (assoc-in current-state [:entries-map ts] msg-payload)]
    {:new-state new-state}))

(def entry-handler-map
  {:entry/new          new-entry-fn
   :entry/found        found-entry-fn
   :entry/geo-enrich   geo-enrich-fn
   :entry/update-local update-local-fn
   :entry/update       update-fn
   :entry/remove-local remove-local-fn
   :entry/saved        entry-saved-fn
   :cmd/pomodoro-inc   pomodoro-inc-fn
   :cmd/pomodoro-start pomodoro-start-fn})
