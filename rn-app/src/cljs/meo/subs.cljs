(ns meo.subs
  (:require [re-frame.core :refer [reg-sub]]
            [meo.ui.colors :as c]))

(reg-sub :stats (fn [db _] (:stats db)))
(reg-sub :entries (fn [db _] (:entries db)))
(reg-sub :all-timestamps (fn [db _] (:all-timestamps db)))
(reg-sub :entry-detail (fn [db _] (:entry-detail db)))

(reg-sub :active-theme (fn [db _] (:active-theme db)))
(reg-sub :current-activity (fn [db _] (:current-activity db)))

(reg-sub :colors (fn [db color]
                   (let [theme (:active-theme db)]
                     (get-in c/colors [color theme]))))
