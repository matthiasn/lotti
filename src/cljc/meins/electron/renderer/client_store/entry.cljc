(ns meins.electron.renderer.client-store.entry
  (:require #?(:cljs [meins.electron.renderer.localstorage :as sa])
            #?(:clj  [taoensso.timbre :refer [debug info]]
               :cljs [taoensso.timbre :refer [debug info]])
            #?(:cljs ["moment" :as moment])
            [matthiasn.systems-toolbox.component :as st]
            [meins.common.utils.misc :as u]
            [meins.common.utils.parse :as p]))

#?(:clj  (defonce new-entries-ls (atom {}))
   :cljs (defonce new-entries-ls (sa/local-storage
                                   (atom {}) "meins_new_entries")))

(defn update-local-storage
  "Updates local-storage with the provided new-entries."
  [state]
  (reset! new-entries-ls (:new-entries state)))

(defn toggle-set-fn
  "Toggles for example the visibility of a map or the edit mode for an individual
  journal entry. Requires the key to exist on the application state as a set."
  [{:keys [current-state msg-payload]}]
  (let [path (:path msg-payload)
        timestamp (:timestamp msg-payload)
        new-state (if (contains? (get-in current-state path) timestamp)
                    (update-in current-state path disj timestamp)
                    (update-in current-state path conj timestamp))]
    {:new-state new-state}))

(defn toggle-key-fn
  "Toggles config key."
  [{:keys [current-state msg-payload]}]
  (let [path (:path msg-payload)]
    {:new-state (update-in current-state path not)}))

(defn new-entry-fn
  "Create locally stored new entry for further edit."
  [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        new-state (assoc-in current-state [:new-entries ts] msg-payload)]
    (update-local-storage new-state)
    {:new-state new-state}))

(defn entry-day [adjusted_ts]
  #?(:clj (prn adjusted_ts)
     :cljs (.format (moment adjusted_ts) "YYYY-MM-DD")))

(defn entry-saved-fn
  "Remove new entry from local when saving is confirmed by backend."
  [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        curr-local (get-in current-state [:new-entries ts])
        new-state (if (or (= (:md curr-local)
                             (:md msg-payload))
                          (not curr-local))
                    (-> current-state
                        (update-in [:new-entries] dissoc ts)
                        (assoc-in [:busy-status :busy] false)
                        (assoc-in [:entries-map ts] msg-payload))
                    current-state)]
    (debug "entry saved, clearing" msg-payload)
    (update-local-storage new-state)
    {:new-state new-state}))

(defn play-audio
  "Start playing audio element with provided DOM id."
  [id]
  #?(:clj (prn id)
     :cljs (.play (.getElementById js/document id))))

(defn parse-int-js [n]
  #?(:cljs (js/parseInt n)
     :clj  n))

(defn pomodoro-inc
  "Increments completed time for entry."
  [{:keys [current-state msg-payload put-fn]}]
  (let [ts (:timestamp msg-payload)
        started (:started msg-payload)
        completed-time (:completed_time msg-payload)
        dur (parse-int-js (+ completed-time
                             (/ (- (st/now) started) 1000)))
        new-state (assoc-in current-state [:new-entries ts :completed_time] dur)]
    (debug "pomodoro-inc-fn" msg-payload)
    (when (get-in current-state [:new-entries ts])
      (let [new-entry (get-in new-state [:new-entries ts])
            completed (:completed_time new-entry)
            comment-for (:comment_for new-entry)
            planned (:planned-dur new-entry 1500)
            time-up? (> completed planned)
            progress (min (/ completed planned) 1)
            cfg (:cfg current-state)
            new-state (-> new-state
                          (assoc-in [:busy-status :busy] (not time-up?))
                          (assoc-in [:busy-status :last] (st/now))
                          (assoc-in [:busy-status :current] ts)
                          (assoc-in [:busy-status :active] comment-for))]
        (when (zero? (mod completed 3))
          (debug "setting progress" progress)
          (put-fn [:window/progress {:v progress}]))
        (if (and (:pomodoro-running new-entry)
                 (= (:running (:pomodoro current-state)) ts))
          (let [color (if time-up? :orange :red)
                new-state (assoc-in new-state [:busy-status :color] color)]
            (when (and (= :orange color)
                       (not= :orange (:color (:busy-status current-state))))
              (put-fn [:blink/busy {:color :orange}])
              (when (:pause-spotify cfg) (put-fn [:spotify/pause])))
            (when-not (:mute cfg)
              (if time-up? (play-audio "ringer")
                           (when (:ticking-clock cfg)
                             (play-audio "ticking-clock"))))
            (update-local-storage new-state)
            {:new-state new-state
             :emit-msg  [[:schedule/new
                          {:timeout 1000
                           :id      (keyword (str "timer-" ts))
                           :message [:cmd/pomodoro-inc
                                     {:started        started
                                      :completed_time completed-time
                                      :timestamp      ts}]}]]})
          {:new-state current-state})))))

(defn pomodoro-start
  "Start pomodoro for entry. Will toggle the :pomodoro-running status of the
   entry and schedule an initial increment message."
  [{:keys [current-state msg-payload]}]
  (info "pomodoro-start-fn" msg-payload)
  (let [ts (:timestamp msg-payload)
        new-entry (assoc-in msg-payload [:pomodoro-running] true)
        new-state (-> current-state
                      (assoc-in [:new-entries ts] new-entry)
                      (assoc-in [:pomodoro :running] ts)
                      (assoc-in [:busy-status :busy] false))]
    (update-local-storage new-state)
    {:new-state new-state
     :emit-msg  [:schedule/new
                 {:message [:cmd/pomodoro-inc
                            {:started        (st/now)
                             :completed_time (:completed_time new-entry)
                             :timestamp      ts}]
                  :timeout 1
                  :id      (keyword (str "timer-" ts))}]}))

(defn pomodoro-stop [{:keys [current-state]}]
  (let [new-state (-> current-state
                      (assoc-in [:pomodoro :running] nil)
                      (assoc-in [:busy-status :busy] false))]
    {:new-state new-state}))

(defn update-local
  "Update locally stored new entry with changes from edit element."
  [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        saved (get-in current-state [:entries-map ts])
        relevant #(select-keys % [:md :questionnaires :custom_fields :task
                                  :habit :completed_time :starred :img-size
                                  :primary_story :story_name :flagged :perm_tags
                                  :adjusted_ts :custom_field_cfg :saga_cfg :tags
                                  :dashboard_cfg :story_cfg :stars :album_cfg
                                  :linked_saga :problem_cfg :problem_review
                                  :latitude :longitude])
        changed? (not= (relevant saved) (relevant msg-payload))]
    (if changed?
      (let [new-entry (get-in current-state [:new-entries ts])
            entry (u/deep-merge saved new-entry msg-payload)
            md (:md entry)
            parsed (when md (p/parse-entry md))
            updated (merge entry parsed)
            updated (if (-> updated :questionnaires :pomo1)
                      (update-in updated [:tags] conj "#PSS")
                      updated)
            new-state (assoc-in current-state [:new-entries ts] updated)]
        (update-local-storage new-state)
        {:new-state new-state})
      {})))

(defn update-merged
  "Update local entry with payload and save in backend."
  [{:keys [current-state msg-payload put-fn]}]
  (let [ts (:timestamp msg-payload)
        new-entry (get-in current-state [:new-entries ts])
        entry (u/deep-merge new-entry msg-payload)]
    (put-fn [:entry/update entry])
    {}))

(defn remove-local [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        new-state (update-in current-state [:new-entries] dissoc ts)]
    (update-local-storage new-state)
    {:new-state new-state}))

(defn geo-res [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        geoname (:geoname msg-payload)
        new-state (assoc-in current-state [:new-entries ts :geoname] geoname)]
    {:new-state new-state}))

(defn set-geolocation [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        new-state (update-in current-state [:new-entries ts] merge msg-payload)]
    {:new-state new-state}))

(def entry-handler-map
  {:entry/new           new-entry-fn
   :entry/update-local  update-local
   :entry/set-geo       set-geolocation
   :entry/update-merged update-merged
   :entry/remove-local  remove-local
   :entry/saved         entry-saved-fn
   :geonames/res        geo-res
   :cmd/pomodoro-inc    pomodoro-inc
   :cmd/pomodoro-start  pomodoro-start
   :cmd/pomodoro-stop   pomodoro-stop})
