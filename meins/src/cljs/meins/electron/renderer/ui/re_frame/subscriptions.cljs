(ns meins.electron.renderer.ui.re-frame.subscriptions
  (:require [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [re-frame.core :refer [reg-sub]]
            [reagent.core :as rc]
            [taoensso.timbre :refer [debug error info]]))

; to be overwritten with put-fn on ui startup
(def emit-atom (atom (fn [])))
(defn emit [m] (@emit-atom m))


;; Subscription Handlers
(reg-sub :gql-res (fn [db _] (:gql-res db)))
(reg-sub :gql-res2 (fn [db _] (:gql-res2 db)))
(reg-sub :dashboard-data (fn [db _] (:dashboard-data db)))

(reg-sub :manual (fn [db _] (:manual db)))

(reg-sub :dashboard (fn [db _] (:dashboard db)))

(reg-sub :habits (fn [db _]
                   (->> (:gql-res db)
                        :habits-success
                        :data
                        :habits_success
                        (map (fn [x] [(:timestamp (:habit_entry x)) x]))
                        (into {}))))

(reg-sub :metrics (fn [db _] (:metrics db)))
(reg-sub :db (fn [db _] db))
(reg-sub :stories (fn [db _]
                    (->> (get-in db [:gql-res :options :data :stories])
                         (map (fn [x] [(:timestamp x) x]))
                         (into {}))))
(reg-sub :sagas (fn [db _]
                  (->> (get-in db [:gql-res :options :data :sagas])
                       (map (fn [x] [(:timestamp x) x]))
                       (into {}))))

(reg-sub :briefing (fn [db _] (get-in db [:gql-res :briefing :data :briefing])))

(reg-sub :briefings (fn [db _]
                      (->> (get-in db [:gql-res :options :data :briefings])
                           (map (fn [m] [(:day m) (:timestamp m)]))
                           (into {}))))

(reg-sub :options (fn [db _] (:options db)))
(reg-sub :imap-status (fn [db _] (:imap-status db)))
(reg-sub :imap-cfg (fn [db _] (:imap-cfg db)))
(reg-sub :custom-field-stats (fn [db _] (:custom-field-stats db)))
(reg-sub :git-stats (fn [db _] (:git-commits db)))
(reg-sub :last-update (fn [db _] (:last-update (:query-cfg db))))
(reg-sub :startup-progress (fn [db _] (:startup-progress db)))
(reg-sub :running-pomodoro (fn [db _] (:running (:pomodoro db))))
(reg-sub :story-predict (fn [db _] (:story-predict db)))
(reg-sub :current-page (fn [db _] (:current-page db)))
(reg-sub :show-pvt (fn [db _] (:show-pvt (:cfg db))))
(reg-sub :show-hidden (fn [db _] (:show-hidden (:cfg db))))
(reg-sub :cal-day (fn [db _] (-> db :cfg :cal-day)))
(reg-sub :busy-status (fn [db _] (:busy-status db)))
(reg-sub :query-cfg (fn [db _] (:query-cfg db)))
(reg-sub :crypto-cfg (fn [db _] (:crypto-cfg db)))
(reg-sub :widgets (fn [db _] (:widgets (:cfg db))))
(reg-sub :questionnaires (fn [db _] (:questionnaires (:options db))))
(reg-sub :dashboards (fn [db _] (:dashboards (:questionnaires (:options db)))))
(reg-sub :active-dashboard (fn [db _] (:active (:dashboard (:cfg db)))))
(reg-sub :entries-map (fn [db _] (:entries-map db)))
(reg-sub :results (fn [db _] (:results db)))
(reg-sub :new-entries (fn [db _] (:new-entries db)))

(reg-sub
  :logged-duration
  (fn [db [_ entry]]
    (let [new-entries (:new-entries db)
          logged-duration (eu/logged-total new-entries entry)]
      (when (pos? logged-duration)
        (h/s-to-hh-mm-ss logged-duration)))))

(reg-sub :cfg (fn [db _] (:cfg db)))
(reg-sub :locale (fn [db _] (:locale (:cfg db) :en)))
(reg-sub :backend-cfg (fn [db _] (:backend-cfg db)))
(reg-sub :repos (fn [db _] (:repos (:backend-cfg db))))
(reg-sub :stats (fn [db _] (:stats db)))
(reg-sub :timing (fn [db _] (:timing db)))
(reg-sub :geo-photos (fn [db _] (:geo-photos db)))
(reg-sub :chart-data (fn [db _] (select-keys db [:media-stats])))
(reg-sub :updater-status (fn [db _] (:updater-status db)))

(reg-sub :hashtags (fn [db _]
                     (let [show-pvt? (:show-pvt (:cfg db))
                           gql-res (:gql-res db)
                           hashtags (-> gql-res :options :data :hashtags)
                           pvt-hashtags (-> gql-res :options :data :pvt_hashtags)
                           hashtags (if show-pvt? pvt-hashtags hashtags)]
                       (map (fn [h] {:name h}) hashtags))))

(reg-sub :mentions (fn [db _]
                     (map (fn [m] {:name m})
                          (get-in db [:gql-res :options :data :mentions]))))
