(ns meo.electron.renderer.ui.entry.location
  (:require [matthiasn.systems-toolbox.component :as st]
            [clojure.string :as s]
            [meo.electron.renderer.helpers :as h]
            [clojure.pprint :as pp]
            [reagent.core :as r]))

(defn location-details
  [entry put-fn edit-mode?]
  (let [input-fn (fn [entry f k]
                   (fn [ev]
                     (let [n (f (-> ev .-nativeEvent .-target .-value))
                           updated (assoc-in entry [:location k] n)]
                       (put-fn [:entry/update-local updated]))))]
    (fn location-details-render [entry put-fn edit-mode?]
      (when-let [location (:location entry)]
        [:form.task-details
         [:fieldset
          [:legend "Location details"]
          [:div
           [:span " Location name: "]
           (if edit-mode?
             [:input {:type      :text
                      :on-change (input-fn entry identity :name)
                      :value     (:name location)}]
             [:span (:name location)])]
          [:div
           [:span " Radius/m: "]
           (if edit-mode?
             [:input {:type      :number
                      :on-change (input-fn entry js/parseInt :radius)
                      :value     (:radius location)}]
             [:span (:radius location)])]]]))))

(defn geonames
  [entry put-fn edit-mode?]
  (let [detail (r/atom false)
        emoji-flags (aget js/window "deps" "emojiFlags")
        toggle-detail (fn [_] (swap! detail not))
        remove #(put-fn [:entry/update (assoc-in @entry [:geoname] :removed)])]
    (fn location-details-render [entry put-fn edit-mode?]
      (let [geoname (:geoname @entry)]
        (when (and geoname (not= :removed geoname))
          (let [{:keys [admin-4-name admin-3-name admin-2-name country-code]} geoname
                flag (get (js->clj (.countryCode emoji-flags country-code)) "emoji")]
            [:div {:on-click toggle-detail}
             [:span.geoname (:name geoname)]
             (when (and @detail admin-4-name) [:span.geoname ", " admin-4-name])
             (when (and @detail admin-3-name) [:span.geoname ", " admin-3-name])
             (when (and @detail admin-2-name) [:span.geoname ", " admin-2-name])
             (when-let [admin-1-name (:admin-1-name geoname)]
               [:span.geoname ", " admin-1-name])
             (when @detail [:span.fa.fa-trash.up {:on-click remove}])
             [:span.flag flag]]))))))
