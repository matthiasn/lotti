(ns meo.electron.renderer.ui.re-frame
  (:require-macros [reagent.ratom :refer [reaction]])
  (:require [reagent.core :as rc]
            [re-frame.core :refer [reg-sub subscribe]]
            [meo.electron.renderer.ui.re-frame.db :as rfd]
            [meo.electron.renderer.ui.re-frame.subscriptions]
            [re-frame.db :as rdb]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [electron :refer [remote]]
            [taoensso.timbre :refer [info error debug]]
            [meo.electron.renderer.ui.menu :as menu]
            [meo.electron.renderer.ui.heatmap :as hm]
            [meo.electron.renderer.ui.grid :as g]
            [meo.electron.renderer.ui.stats :as stats]
            [meo.electron.renderer.ui.footer :as f]
            [meo.electron.renderer.ui.config.core :as cfg]
            [meo.electron.renderer.ui.charts.correlation :as corr]
            [meo.electron.renderer.ui.charts.location :as loc]
            [meo.electron.renderer.ui.img.core :as ic]
            [meo.electron.renderer.ui.entry.briefing.calendar :as cal]
            [meo.electron.renderer.ui.entry.briefing :as b]
            [meo.electron.renderer.ui.data-explorer :as dex]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.updater :as upd]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.electron.renderer.ui.help :as help]))

(defn main-page []
  (let [cfg (subscribe [:cfg])
        single-column (reaction (:single-column @cfg))]
    (fn []
      [:div.flex-container
       [:div.grid
        [:div.wrapper.col-3
         [h/error-boundary [menu/menu-view]]
         [h/error-boundary [menu/busy-status]]
         [h/error-boundary [cal/infinite-cal]]
         [h/error-boundary [cal/calendar-view]]
         [h/error-boundary [b/briefing-column-view :briefing]]
         [:div {:class (if @single-column "single" "left")}
          [h/error-boundary [g/tabs-view :left]]]
         (when-not @single-column
           [:div.right
            [h/error-boundary [g/tabs-view :right]]])
         [h/error-boundary
          [f/dashboard]]]]
       [h/error-boundary
        [stats/stats-text]]
       [h/error-boundary
        [upd/updater]]])))

(defn countries-page []
  [:div.flex-container
   [loc/location-chart]])

(defn cal []
  [:div.flex-container
   [cal/calendar-view]])

(defn load-progress []
  (let [startup-progress (subscribe [:startup-progress])]
    (fn []
      (let [startup-progress @startup-progress
            percent (Math/floor (* 100 startup-progress))]
        [:div.loader
         [:div.content
          [:h1 "starting meo v" (.getVersion (aget remote "app")) "..."]
          [:div.meter
           [:span {:style {:width (str percent "%")}}]]]]))))

(defn re-frame-ui []
  (let [current-page (subscribe [:current-page])
        startup-progress (subscribe [:startup-progress])
        cfg (subscribe [:cfg])
        data-explorer (reaction (:data-explorer @cfg))]
    (fn []
      (let [current-page @current-page
            startup-progress @startup-progress]
        (when-not @data-explorer
          (aset js/document "body" "style" "overflow" "hidden"))
        (if (= 1 startup-progress)
          [:div
           (case (:page current-page)
             :config [cfg/config]
             :countries [countries-page ]
             :calendar [cal]
             :correlation [corr/scatter-matrix]
             :heatmap [hm/heatmap]
             :gallery [ic/gallery-page]
             :help [help/help]
             :empty [:div.flex-container]
             [main-page])
           (when @data-explorer
             [dex/data-explorer])]
          [load-progress ])))))

(defn state-fn [put-fn]
  (reset! rfd/emit-atom put-fn)
  (rc/render [re-frame-ui] (.getElementById js/document "reframe"))
  {:observed rdb/app-db})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
