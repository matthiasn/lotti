(ns meo.electron.renderer.ui.entry.datetime
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.common.utils.misc :as u]
            [meo.electron.renderer.helpers :as h]
            [reagent.core :as r]
            [moment]))

(defn datetime-header [entry put-fn]
  (let [cfg (subscribe [:cfg])
        local (r/atom {:show-adjust-ts false})
        toggle-adjust #(swap! local update-in [:show-adjust-ts] not)
        ts (:timestamp entry)]
    (fn [entry put-fn]
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
         (if (:show-adjust-ts @local)
           [:div.adjust
            [:i.far.fa-clock]
            [:time {:on-click toggle-adjust}
             (h/localize-datetime (moment ts) locale)]
            [:i.far.fa-pencil-alt]
            [:input {:type        :datetime-local
                     :on-change   on-change
                     :on-key-down (h/key-down-save entry put-fn)
                     :value       (h/format-time (or adjusted-ts ts))}]
            [:i.far.fa-trash-alt
             {:on-click rm-adjusted-ts}]]
           [:a [:time.ts
                {:on-click toggle-adjust
                 :class    (when (and adjusted-ts (not= adjusted-ts ts))
                             "adjusted")}
                formatted-time]])
         [:time (u/visit-duration entry)]]))))
