(ns meo.electron.renderer.ui.footer
  (:require [meo.electron.renderer.ui.stats :as stats]
            [meo.electron.renderer.ui.dashboard :as db]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]))

(defn footer [put-fn]
  (let [cfg (subscribe [:cfg])
        dashboard-banner (reaction (:dashboard-banner @cfg))
        local (r/atom {:height 200})
        dashboards (subscribe [:dashboards])
        active-dashboard (subscribe [:active-dashboard])
        increase-height #(swap! local update-in [:height] + 5)
        decrease-height #(swap! local update-in [:height] - 5)
        select (fn [ev]
                 (let [sel (keyword (-> ev .-nativeEvent .-target .-value))]
                   (put-fn [:cmd/assoc-in
                            {:path  [:cfg :dashboard :active]
                             :value sel}])))]
    (fn [put-fn]
      [:div.footer
       (when @dashboard-banner
         [:div
          [db/dashboard put-fn]
          [:div
           [:select {:value     (or @active-dashboard "")
                     :on-change select}
            (for [dashboard-id (keys @dashboards)]
              ^{:key dashboard-id}
              [:option {:value dashboard-id} (name dashboard-id)])]]])])))
