(ns meo.electron.renderer.ui.entry.datetime
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.common.utils.misc :as u]
            [meo.electron.renderer.helpers :as h]
            [reagent.core :as r]
            [moment]))

(defn datetime-header [entry local put-fn]
  (let [cfg (subscribe [:cfg])
        toggle-adjust #(swap! local update-in [:show-adjust-ts] not)
        ts (:timestamp entry)]
    (fn [entry local put-fn]
      (let [locale (:locale @cfg :en)
            adjusted-ts (:adjusted_ts entry)
            formatted-time (h/localize-datetime (moment (or adjusted-ts ts)) locale)]
        [:div.datetime
         [:a [:time.ts
              {:on-click toggle-adjust
               :class    (when (and adjusted-ts (not= adjusted-ts ts))
                           "adjusted")}
              formatted-time]]
         [:time (u/visit-duration entry)]]))))

(defn datetime-edit [entry local put-fn]
  (let [cfg (subscribe [:cfg])
        toggle-adjust #(swap! local update-in [:show-adjust-ts] not)
        ts (:timestamp entry)]
    (fn [entry local put-fn]
      (let [locale (:locale @cfg :en)
            adjusted-ts (:adjusted_ts entry)
            formatted-time (h/localize-datetime (moment (or adjusted-ts ts)) locale)
            on-change (fn [ev]
                        (let [adjusted-ts (.valueOf (moment (h/target-val ev)))
                              updated (assoc-in entry [:adjusted_ts] adjusted-ts)]
                          (put-fn [:entry/update-local updated])))
            rm-adjusted-ts (fn [_]
                             (let [updated (assoc-in entry [:adjusted_ts] ts)]
                               (put-fn [:entry/update-local updated])
                               (toggle-adjust)))]
        [:div.datetime
         [:div.adjust
          [:div
           [:i.far.fa-pencil-alt]
           [:input {:type        :datetime-local
                    :on-change   on-change
                    :on-key-down (h/key-down-save entry put-fn)
                    :value       (h/format-time (or adjusted-ts ts))}]
           [:i.far.fa-trash-alt
            {:on-click rm-adjusted-ts}]]]]))))
