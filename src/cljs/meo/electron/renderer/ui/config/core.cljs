(ns meo.electron.renderer.ui.config.core
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error]]
            [meo.electron.renderer.ui.config.custom-fields :as cf]
            [meo.electron.renderer.ui.config.habits :as ch]
            [meo.electron.renderer.ui.config.metrics :as cm]
            [meo.electron.renderer.ui.config.locale :as cl]
            [meo.electron.renderer.ui.config.sync :as sync]
            [meo.electron.renderer.ui.stats :as stats]
            [meo.electron.renderer.ui.menu :as menu]
            [meo.electron.renderer.helpers :as h]
            [reagent.core :as r]
            [moment]))

(defn config [_put-fn]
  (let [local (r/atom {:search          ""
                       :new-field-input ""
                       :page            :custom-fields})
        menu-item (fn [k t active]
                    [:div.menu-item
                     {:on-click #(swap! local assoc-in [:page] k)
                      :class    (when (= active k) "active")}
                     t])]
    (fn config-render [put-fn]
      (let [page (:page @local)]
        [:div.flex-container
         [:div.grid
          [:div.wrapper
           [menu/menu-view put-fn]
           [:div.config
            [:div.menu
             [:h1 "Settings"]
             [menu-item :custom-fields "Custom Fields" page]
             [menu-item :habits "Habits" page]
             [menu-item :metrics "Metrics" page]
             [menu-item :sync "Synchronization" page]
             [menu-item :photos "Photos" page]
             [menu-item :localization "Localization" page]
             [menu-item :playground "Playground" page]
             [:div.menu-item.exit
              {:on-click #(put-fn [:nav/to {:page :main}])}
              "Exit"]]
            (when (= :custom-fields page)
              [h/error-boundary
               [cf/custom-fields-list local put-fn]])
            (when (and (= :custom-fields page) (:selected @local))
              [h/error-boundary
               [cf/custom-field-tab :custom_field_cfg put-fn]])
            (when (= :localization page)
              [cl/locale-preferences put-fn])
            (when (= :habits page)
              [ch/habits-row local put-fn])
            (when (= :sync page)
              [sync/sync put-fn])
            (when (= :metrics page)
              [cm/metrics put-fn])
            (when (= :photos page)
              [:div.photos
               [:button {:on-click #(put-fn [:photos/gen-cache])}
                "regenerate cache"]])]
           [:div.cfg.footer [stats/stats-text true]]]]]))))
