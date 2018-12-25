(ns meo.electron.renderer.ui.entry.cfg.album
  (:require [meo.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.ui.entry.cfg.shared :as cs]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [taoensso.timbre :refer-macros [info error debug]]))

(defn album-config [_]
  (let [title-path [:album_cfg :title]]
    (fn [entry]
      (let []
        [:div.habit-details.album
         [cs/input-row entry {:label "Album Title "
                              :path  title-path
                              :type  "text"} emit]
         [:div.row
          [:label "Active? "]
          [uc/switch {:entry entry :path [:album_cfg :active]}]]
         [:div.row
          [:label "Private? "]
          [uc/switch {:entry entry :path [:album_cfg :pvt]}]]]))))
