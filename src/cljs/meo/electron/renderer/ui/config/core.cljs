(ns meo.electron.renderer.ui.config.core
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error]]
            [meo.electron.renderer.ui.config.custom-fields :as cf]
            [meo.electron.renderer.ui.config.sagas :as cs]
            [meo.electron.renderer.ui.config.stories :as cst]
            [meo.electron.renderer.ui.config.habits :as ch]
            [meo.electron.renderer.ui.config.metrics :as cm]
            [meo.electron.renderer.ui.config.locale :as cl]
            [meo.electron.renderer.ui.config.sync :as sync]
            [meo.electron.renderer.ui.stats :as stats]
            [meo.electron.renderer.ui.menu :as menu]
            [meo.electron.renderer.helpers :as h]
            [reagent.core :as r]
            [moment]))

(defn config [put-fn]
  (let [local (r/atom {:search          ""
                       :new-field-input ""
                       :section         :sagas
                       :stories_cfg     {:sorted-by :timestamp
                                         :reverse   true}})
        menu-item (fn [k t active]
                    [:div.menu-item
                     {:on-click #(swap! local assoc-in [:page] k)
                      :class    (str
                                  (when (= active k) "active ")
                                  (when (= (:section @local) k) "highlight"))}
                     t])
        sections [:sagas :stories :custom-fields :habits
                  :metrics :sync :photos :localization :exit]
        sections (concat sections sections)
        next-item (fn [coll] (first (rest (drop-while #(not= (:section @local) %) coll))))
        next-page #(swap! local assoc :section (next-item sections))
        prev-page #(swap! local assoc :section (next-item (reverse sections)))
        exit #(do (swap! local dissoc :page) (put-fn [:nav/to {:page :main}]))
        keydown (fn [ev]
                  (let [key-code (.. ev -keyCode)
                        arrow-up (= key-code 38)
                        arrow-left (= key-code 37)
                        arrow-right (= key-code 39)
                        arrow-down (= key-code 40)
                        enter (= key-code 13)
                        esc (= key-code 27)]
                    (info key-code)
                    (if (:page @local)
                      (when (or esc arrow-left)
                        (swap! local dissoc :page))
                      (do
                        (when arrow-down (next-page))
                        (when arrow-up (prev-page))
                        (when (or arrow-right enter)
                          (if (= :exit (:section @local))
                            (exit)
                            (swap! local assoc :page (:section @local))))))
                    (.stopPropagation ev)))
        did-mount (fn [_]
                    (info "adding event listener")
                    (.addEventListener js/document "keydown" keydown))
        did-unmount #(.removeEventListener js/document "keydown" keydown)
        render (fn [_]
                 (let [page (:page @local)]
                   [:div.flex-container
                    [:div.grid
                     [:div.wrapper
                      [menu/menu-view put-fn]
                      [:div.config
                       [:div.menu
                        [:h1 "Settings"]
                        [menu-item :sagas "Sagas" page]
                        [menu-item :stories "Stories" page]
                        [menu-item :custom-fields "Custom Fields" page]
                        [menu-item :habits "Habits" page]
                        [menu-item :metrics "Metrics" page]
                        [menu-item :sync "Synchronization" page]
                        [menu-item :photos "Photos" page]
                        [menu-item :localization "Localization" page]
                        [:div.menu-item.exit
                         {:on-click exit
                          :class    (when (= :exit (:section @local)) "highlight")}
                         "Exit"]]
                       (when (= :sagas page)
                         [cs/sagas local put-fn])
                       (when (= :stories page)
                         [cst/stories local put-fn])
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
                         [:div.photos.col
                          [:h2 "Photo Settings"]
                          [:button {:on-click #(put-fn [:photos/gen-cache])}
                           "regenerate cache"]])]
                      [:div.cfg.footer [stats/stats-text true]]]]]))]
    (r/create-class
      {:component-did-mount         did-mount
       :component-will-will-unmount did-unmount
       :display-name                "Preferences"
       :reagent-render              render})))