(ns meins.electron.renderer.ui.re-frame
  (:require-macros [reagent.ratom :refer [reaction]])
  (:require [electron :refer [remote]]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.charts.correlation :as corr]
            [meins.electron.renderer.ui.charts.location :as loc]
            [meins.electron.renderer.ui.data-explorer :as dex]
            [meins.electron.renderer.ui.entry.briefing :as b]
            [meins.electron.renderer.ui.entry.briefing.calendar :as cal]
            [meins.electron.renderer.ui.focus :as fc]
            [meins.electron.renderer.ui.footer :as f]
            [meins.electron.renderer.ui.geo.locations-map :as loc-map]
            [meins.electron.renderer.ui.grid :as g]
            [meins.electron.renderer.ui.heatmap :as hm]
            [meins.electron.renderer.ui.help :as help]
            [meins.electron.renderer.ui.img.core :as ic]
            [meins.electron.renderer.ui.menu :as menu]
            [meins.electron.renderer.ui.post-mortems :as pm]
            [meins.electron.renderer.ui.preferences.core :as cfg]
            [meins.electron.renderer.ui.re-frame.db :as rfd]
            [meins.electron.renderer.ui.re-frame.subscriptions]
            [meins.electron.renderer.ui.spotify :as sp]
            [meins.electron.renderer.ui.stats :as stats]
            [meins.electron.renderer.ui.updater :as upd]
            [re-frame.core :refer [subscribe]]
            [re-frame.db :as rdb]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug error info]]))

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
        [stats/stats-text]]])))

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
            lines-prog (Math/floor (* 100 (:lines startup-progress)))
            graph-prog (Math/floor (* 100 (:graph startup-progress)))]
        [:div.loader
         [:div.content
          [:img {:src   "public/images/logo.png"
                 :style {:width 200}}]
          [:div.meter
           [:span {:style {:width (str lines-prog "%")}}]]
          [:div.meter
           [:span {:style {:width (str graph-prog "%")}}]]
          [:h1 "v" (.getVersion (aget remote "app"))]]]))))

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
        (if (= 1 (:graph startup-progress))
          [:div
           (case (:page current-page)
             :config [cfg/config]
             :countries [countries-page]
             :calendar [cal]
             :correlation [corr/scatter-matrix]
             :heatmap [hm/heatmap]
             :locations-map [loc-map/locations-map]
             :gallery [ic/gallery-page]
             :help [help/help]
             :spotify [sp/spotify-view]
             :empty [:div.flex-container]
             :focus [fc/focus-page]
             :post-mortem [pm/post-mortem-page]
             [main-page])
           (when @data-explorer
             [dex/data-explorer])
           [h/error-boundary
            [upd/updater]]]
          [load-progress])))))

(defn state-fn [put-fn]
  (reset! rfd/emit-atom put-fn)
  (r/render [re-frame-ui] (.getElementById js/document "reframe"))
  {:observed rdb/app-db})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
