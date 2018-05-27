(ns meo.electron.renderer.ui.footer
  (:require [meo.electron.renderer.ui.stats :as stats]
            [meo.electron.renderer.ui.dashboard :as db]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]
            [meo.electron.renderer.ui.charts.time.durations :as cd]))

(defn footer [put-fn]
  (let [cfg (subscribe [:cfg])
        dashboard-banner (reaction (:dashboard-banner @cfg))
        local (r/atom {:height "33vh"
                       :days   90})
        show-pvt (subscribe [:show-pvt])
        dashboards (subscribe [:dashboards])
        active-dashboard (subscribe [:active-dashboard])
        select (fn [ev]
                 (let [sel (keyword (-> ev .-nativeEvent .-target .-value))]
                   (put-fn [:cmd/assoc-in
                            {:path  [:cfg :dashboard :active]
                             :value sel}])))
        select-height (fn [ev]
                        (let [h (-> ev .-nativeEvent .-target .-value)]
                          (swap! local assoc-in [:height] h)))
        select-days (fn [ev]
                      (let [d (js/parseInt (-> ev .-nativeEvent .-target .-value))]
                        (swap! local assoc-in [:days] d)
                        (put-fn [:gql/query {:file     "day-stats.gql"
                                             :id       :day-stats
                                             :res-hash nil
                                             :prio     5
                                             :args     [d]}])))]
    (fn [put-fn]
      [:div.footer
       (if @dashboard-banner
         [:div {:style {:max-height (:height @local)}}
          [db/dashboard (:days @local) put-fn]
          (when @show-pvt
            [:div
             [:select {:value     (or @active-dashboard "")
                       :on-change select}
              (for [dashboard-id (keys @dashboards)]
                ^{:key dashboard-id}
                [:option {:value dashboard-id} (name dashboard-id)])]
             [:select {:value     (:height @local)
                       :on-change select-height}
              [:option {:value "20vh"} "20%"]
              [:option {:value "33vh"} "33%"]
              [:option {:value "50vh"} "50%"]
              [:option {:value "66vh"} "66%"]
              [:option {:value "75vh"} "75%"]
              [:option {:value "100vh"} "100%"]]
             [:select {:value     (:days @local)
                       :on-change select-days}
              [:option {:value 30} "30 days"]
              [:option {:value 60} "60 days"]
              [:option {:value 90} "90 days"]
              [:option {:value 120} "120 days"]
              [:option {:value 150} "150 days"]
              [:option {:value 180} "180 days"]
              [:option {:value 270} "270 days"]
              [:option {:value 365} "1 year"]]])
          [stats/stats-text]]
         [stats/stats-text])])))
