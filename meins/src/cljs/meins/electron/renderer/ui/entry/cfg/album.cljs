(ns meins.electron.renderer.ui.entry.cfg.album
  (:require [meins.electron.renderer.ui.entry.cfg.shared :as cs]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.ui-components :as uc]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug error info]]))

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
