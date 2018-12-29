(ns meo.electron.renderer.ui.entry.cfg.album
  (:require [meo.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.ui.entry.cfg.shared :as cs]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [taoensso.timbre :refer-macros [info error debug]]
            [reagent.core :as r]))

(defn album-config [entry]
  (let [title-path [:album_cfg :title]
        task? (contains? (:perm_tags entry) "#task")
        local (r/atom {:show (not task?)})]
    (fn [entry]
      (let [show (:show @local)]
        [:div.habit-details.album
         (when task?
           [:div.detail-switch {:on-click #(swap! local update :show not)}
            "Album details"
            [:span [:i.fas {:class (if show
                                     "fa-chevron-square-up"
                                     "fa-chevron-square-down")}]]])
         (when show
           [:div
            [cs/input-row entry {:label "Album Title "
                                 :path  title-path
                                 :type  "text"} emit]
            [:div.row
             [:label "Private? "]
             [uc/switch {:entry entry :path [:album_cfg :pvt]}]]])]))))
