(ns meins.electron.renderer.client-store.handlers
  (:require #?(:cljs [reagent.core :refer [atom]])
            #?(:clj  [taoensso.timbre :refer [info debug]]
               :cljs [taoensso.timbre :refer-macros [info debug]])))

(defn nav-handler [{:keys [current-state msg-payload]}]
  (let [old-page (:page (:current-page current-state))
        new-page (:page msg-payload)
        toggle (:toggle msg-payload)
        new-page (if (and toggle (= old-page new-page)) toggle new-page)
        new-state (assoc-in current-state [:current-page] {:page new-page})]
    {:new-state new-state}))

(defn blink-busy [{:keys [current-state msg-payload]}]
  (let [color (:color msg-payload)
        new-state (assoc-in current-state [:busy-status :color] color)]
    {:new-state new-state}))

(defn save-backend-cfg [{:keys [current-state msg-payload]}]
  (let [new-state (-> (assoc-in current-state [:backend-cfg] msg-payload)
                      (assoc-in [:options :custom-fields] (:custom-fields msg-payload))
                      (assoc-in [:options :questionnaires] (:questionnaires msg-payload))
                      (assoc-in [:options :custom-field-charts] (:custom-field-charts msg-payload)))]
    {:new-state new-state}))

(defn progress [{:keys [current-state msg-payload]}]
  (let [new-state (update-in current-state [:startup-progress] merge msg-payload)]
    {:new-state new-state}))

(defn save-metrics [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:metrics] msg-payload)]
    {:new-state new-state}))

(defn save-dashboard-data-by-tag [state coll]
  (let [f (fn [acc {:keys [tag date_string] :as m}]
            (let [path [:dashboard-data date_string :custom-fields tag]]
              (assoc-in acc path m)))]
    (reduce f state coll)))

(defn save-questionnaire-data-by-tag [state coll]
  (let [f (fn [acc {:keys [tag agg date_string] :as m}]
            (let [path [:dashboard-data date_string :questionnaires tag agg]]
              (update-in acc path #(conj (set %) m))))]
    (reduce f state coll)))

(defn save-habits-by-day [state coll]
  (let [f (fn [acc {:keys [day habit_ts success] :as m}]
            (let [path [:dashboard-data day :habits habit_ts]]
              (assoc-in acc path m)))]
    (reduce f state coll)))

(defn save-day-stats-by-day [state coll]
  (let [f (fn [acc {:keys [day by_saga] :as m}]
            (let [path [:dashboard-data day :by-saga]
                  by-saga (reduce (fn [acc x]
                                    (let [ts (:timestamp (:saga x))
                                          logged (:logged x)]
                                      (assoc acc ts logged)))
                                  {} by_saga)]
              (assoc-in acc path by-saga)))]
    (reduce f state coll)))

(defn save-dashboard-data [state res]
  (let [data (-> res :data vals)
        id (:id res)
        f (case id
            :custom-fields-by-days save-dashboard-data-by-tag
            :questionnaires-by-days save-questionnaire-data-by-tag
            :habits-by-days save-habits-by-day
            :day-stats save-day-stats-by-day
            nil)]
    (if f
      (reduce f state data)
      state)))

(defn gql-res [{:keys [current-state msg-payload]}]
  (let [{:keys [id]} msg-payload
        new-state (assoc-in current-state [:gql-res id] msg-payload)
        new-state (save-dashboard-data new-state msg-payload)]
    {:new-state new-state}))

(defn imap-status [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:imap-status] msg-payload)]
    {:new-state new-state}))

(defn imap-cfg [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:imap-cfg] msg-payload)]
    {:new-state new-state}))

(defn save-manual [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:manual] msg-payload)]
    {:new-state new-state}))

(defn ping [_]
  #?(:cljs (info :ping))
  {})

(defn set-updater-status
  [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:updater-status] msg-payload)]
    {:new-state new-state}))
