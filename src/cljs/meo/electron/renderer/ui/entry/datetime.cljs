(ns meo.electron.renderer.ui.entry.datetime
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.electron.renderer.helpers :as h]
            [meo.common.utils.misc :as u]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [reagent.core :as r]
            [moment]))

(defn datetime-edit [entry local2]
  (let [cfg (subscribe [:cfg])
        toggle-adjust #(swap! local2 update-in [:show-adjust-ts] not)
        ts (:timestamp entry)
        adjusted-ts (:adjusted_ts entry)
        local (r/atom {:value (h/format-time (or adjusted-ts ts))})]
    (fn [entry local2]
      (let [adjusted-ts (:adjusted_ts entry)
            rm-adjusted-ts (fn [_]
                             (let [updated (assoc-in entry [:adjusted_ts] ts)]
                               (emit [:entry/update-local updated])
                               (toggle-adjust)))
            on-change (fn [ev]
                        (let [v (h/target-val ev)
                              adjusted-ts (.valueOf (moment v))
                              _ (info v adjusted-ts)
                              adjusted-ts (if (js/isNaN adjusted-ts)
                                            (:timestamp entry)
                                            adjusted-ts)
                              updated (assoc-in entry [:adjusted_ts] adjusted-ts)]
                          (swap! local assoc :value v)
                          (emit [:entry/update-local updated])))]
        [:div.datetime
         [:div.adjust
          [:div
           [:input {:type        :datetime-local
                    :on-change   on-change
                    :on-key-down (h/key-down-save entry)
                    :value       (:value @local)}]]]]))))

(defn datetime-header [entry local]
  (let [cfg (subscribe [:cfg])
        toggle-adjust #(swap! local update-in [:show-adjust-ts] not)
        ts (:timestamp entry)]
    (fn [entry local]
      (let [locale (:locale @cfg :en)
            adjusted-ts (:adjusted_ts entry)
            formatted-time (h/localize-datetime (moment (or adjusted-ts ts)) locale)]
        [:div.datetime
         [:a [:time.ts
              {:on-click toggle-adjust
               :class    (when (and adjusted-ts (not= adjusted-ts ts))
                           "adjusted")}
              formatted-time]]
         (when-let [visit-dur (h/visit-duration entry)]
           [:span.visit "Visit: "
            [:time visit-dur]])]))))