(ns meins.electron.renderer.ui.preferences.core
  (:require [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.footer :as f]
            [meins.electron.renderer.ui.menu :as menu]
            [meins.electron.renderer.ui.preferences.albums :as ca]
            [meins.electron.renderer.ui.preferences.custom-fields :as cf]
            [meins.electron.renderer.ui.preferences.dashboards :as cd]
            [meins.electron.renderer.ui.preferences.habits :as ch]
            [meins.electron.renderer.ui.preferences.locale :as cl]
            [meins.electron.renderer.ui.preferences.metrics :as cm]
            [meins.electron.renderer.ui.preferences.sagas :as cs]
            [meins.electron.renderer.ui.preferences.stories :as cst]
            [meins.electron.renderer.ui.preferences.sync :as sync]
            [meins.electron.renderer.ui.preferences.usage-stats :as usage]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.stats :as stats]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug error info]]))

(defn config []
  (let [local (r/atom {:search          ""
                       :new-field-input ""
                       :highlighted     :sagas
                       :stories_cfg     {:sorted-by :timestamp
                                         :reverse   true}})
        menu-item (fn [k t active]
                    [:div.menu-item
                     {:on-click #(swap! local merge {:page k :search ""})
                      :class    (str
                                  (when (= active k)
                                    "active ")
                                  (when (and (not active) (= (:highlighted @local) k))
                                    "highlight"))}
                     t])
        sections [:sagas :stories :custom-fields :habits :dashboards
                  :metrics :sync :photos :localization :usage :exit]
        sections (concat sections sections)
        next-item (fn [coll] (first (rest (drop-while #(not= (:highlighted @local) %) coll))))
        next-page #(swap! local assoc :highlighted (next-item sections))
        prev-page #(swap! local assoc :highlighted (next-item (reverse sections)))
        exit #(do (swap! local dissoc :page) (emit [:nav/to {:page :main}]))
        keydown (fn [ev]
                  (let [key-code (.. ev -keyCode)
                        arrow-up (= key-code 38)
                        ;arrow-left (= key-code 37)
                        arrow-right (= key-code 39)
                        arrow-down (= key-code 40)
                        enter (= key-code 13)
                        esc (= key-code 27)]
                    (debug key-code)
                    (if (:page @local)
                      (when esc (swap! local dissoc :page))
                      (let [highlighted (:highlighted @local)]
                        (when arrow-down (next-page))
                        (when arrow-up (prev-page))
                        (when (or arrow-right enter)
                          (if (= :exit highlighted)
                            (exit)
                            (swap! local merge {:page   highlighted
                                                :search ""})))))
                    (.stopPropagation ev)))
        did-mount (fn [_]
                    (info "adding event listener")
                    (.addEventListener js/document "keydown" keydown))
        will-unmount #(.removeEventListener js/document "keydown" keydown)
        render (fn [_]
                 (let [page (:page @local)]
                   [:div.flex-container
                    [:div.grid
                     [:div.wrapper
                      [menu/menu-view]
                      [:div.config
                       [:div.menu
                        [:h1 "Settings"]
                        [:div.items
                         [menu-item :sagas "Sagas" page]
                         [menu-item :stories "Stories" page]
                         [menu-item :albums "Albums" page]
                         [menu-item :custom-fields "Custom Fields" page]
                         [menu-item :habits "Habits" page]
                         [menu-item :dashboards "Dashboards" page]
                         [menu-item :metrics "Metrics" page]
                         [menu-item :sync "Synchronization" page]
                         [menu-item :photos "Photos" page]
                         [menu-item :localization "Localization" page]
                         [menu-item :usage "Usage Stats" page]
                         [:div.menu-item.exit
                          {:on-click exit
                           :class    (when (= :exit (:highlighted @local)) "highlight")}
                          "Exit"]]]
                       (when (= :sagas page)
                         [cs/sagas local])
                       (when (= :albums page)
                         [ca/albums local])
                       (when (= :stories page)
                         [cst/stories local])
                       (when (= :custom-fields page)
                         [h/error-boundary
                          [cf/custom-fields-list local]])
                       (when (and (= :custom-fields page) (:selected @local))
                         [h/error-boundary
                          [cf/custom-field-tab :custom_field_cfg]])
                       (when (= :localization page)
                         [cl/locale-preferences])
                       (when (= :habits page)
                         [ch/habits-row local])
                       (when (= :dashboards page)
                         [cd/dashboards-row local])
                       (when (= :sync page)
                         [sync/sync])
                       (when (= :usage page)
                         [usage/usage])
                       (when (= :metrics page)
                         [cm/metrics])
                       (when (= :photos page)
                         [:div.photos.col
                          [:h2 "Photo Settings"]
                          [:button {:on-click #(emit [:photos/gen-cache])}
                           "regenerate cache"]])]
                      (when (= :dashboards page)
                        [h/error-boundary
                         [f/dashboard]])
                      [:div.cfg.footer [stats/stats-text true]]]]]))]
    (r/create-class
      {:component-did-mount    did-mount
       :component-will-unmount will-unmount
       :display-name           "Preferences"
       :reagent-render         render})))