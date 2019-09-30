(ns meins.electron.renderer.ui.entry.location
  (:require [clojure.pprint :as pp]
            [clojure.string :as s]
            [emoji-flags]
            [matthiasn.systems-toolbox.component :as st]
            [meins.electron.renderer.helpers :as h]
            [reagent.core :as r]))

(defn location-details
  [entry put-fn edit-mode?]
  (let [input-fn (fn [entry f k]
                   (fn [ev]
                     (let [n (f (h/target-val ev))
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

(defn geonames [entry put-fn]
  (let [detail (r/atom false)
        toggle-detail (fn [_] (swap! detail not))]
    (fn location-details-render [entry put-fn]
      (let [geoname (:geoname entry)]
        (when (and geoname (not= :removed geoname))
          (let [{:keys [admin-4-name admin-3-name admin-2-name country-code]} geoname
                loc-name (:name geoname)
                remove #(put-fn [:entry/update-local (assoc-in entry [:geoname] :removed)])
                flag (get (js->clj (.countryCode emoji-flags country-code)) "emoji")]
            [:div.geoname {:on-click toggle-detail}
             (when @detail [:div.loc [:span.fa.fa-trash.up {:on-click remove}]])
             (when (and @detail loc-name) [:div.loc loc-name ", "])
             (when (and @detail (seq admin-4-name)) [:div.loc admin-4-name ", "])
             (when (and @detail (seq admin-3-name)) [:div.loc admin-3-name ", "])
             (when (and @detail (seq admin-2-name)) [:div.loc admin-2-name ", "])
             (when-let [admin-1-name (:admin-1-name geoname)]
               [:div.loc admin-1-name])
             [:div [:span.flag flag]]]))))))
