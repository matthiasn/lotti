(ns meins.ui.settings.health
  (:require [meins.ui.db :refer [emit]]
            [meins.ui.icons.health :as icns]
            [meins.ui.settings.items :refer [item settings-page]]
            [re-frame.core :refer [subscribe]]))

(defn health-settings [_props]
  (let [import (fn [msg-type] (fn [_] (emit [msg-type {:n 30}])))]
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)
            icon-size 26]
        [settings-page
         [item {:label    "Weight"
                :icon     (icns/weight-icon icon-size)
                :on-press (import :healthkit/weight)}]
         [item {:label    "Blood Pressure"
                :icon     (icns/bp-icon icon-size)
                :on-press (import :healthkit/bp)}]
         [item {:label    "Exercise"
                :icon     (icns/exercise-icon icon-size)
                :on-press (import :healthkit/exercise)}]
         [item {:label    "Steps"
                :icon     (icns/steps-icon icon-size)
                :on-press (import :healthkit/steps)}]
         [item {:label    "Energy"
                :icon     (icns/energy-icon icon-size)
                :on-press (import :healthkit/energy)}]
         [item {:label    "Sleep"
                :icon     (icns/sleep-icon icon-size)
                :on-press (import :healthkit/sleep)}]
         [item {:label            "Heart Rate Variability"
                :icon             (icns/hrv-icon icon-size)
                :btm-border-width 0
                :on-press         (import :healthkit/hrv)}]]))))
