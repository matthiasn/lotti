(ns meo.electron.renderer.ui.config.locale
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [taoensso.timbre :refer-macros [info error]]))

(defn locale-preferences []
  (let [cfg (subscribe [:cfg])
        locales {:de "German"
                 :en "English"
                 :fr "French"
                 :es "Spanish"}
        set-locale (fn [ev]
                     (let [sel (keyword (-> ev .-nativeEvent .-target .-value))]
                       (emit [:cmd/toggle-key {:path     [:cfg :locale]
                                                 :reset-to sel}])))]
    (fn []
      [:div.col.locale
       [:h2 "Localization"]
       [:select {:value     (:locale @cfg :en)
                 :on-change set-locale}
        (for [[k locale-name] locales]
          ^{:key k}
          [:option {:value k} locale-name])]])))
