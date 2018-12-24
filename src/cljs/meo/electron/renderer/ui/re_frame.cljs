(ns meo.electron.renderer.ui.re-frame
  (:require-macros [reagent.ratom :refer [reaction]])
  (:require [reagent.core :as rc]
            [re-frame.core :refer [reg-sub subscribe]]
            [meo.electron.renderer.ui.re-frame.db :as rfd]
            [re-frame.db :as rdb]
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

(defn main-page [put-fn]
  (let [cfg (subscribe [:cfg])
        single-column (reaction (:single-column @cfg))]
    (fn [put-fn]
      [:div.flex-container
       [:div.grid
        [:div.wrapper.col-3
         [h/error-boundary [menu/menu-view put-fn]]
         [h/error-boundary [menu/busy-status put-fn]]
         [h/error-boundary [cal/infinite-cal put-fn]]
         [h/error-boundary [cal/calendar-view put-fn]]
         [h/error-boundary [b/briefing-column-view :briefing put-fn]]
         [:div {:class (if @single-column "single" "left")}
          [h/error-boundary [g/tabs-view :left put-fn]]]
         (when-not @single-column
           [:div.right
            [h/error-boundary [g/tabs-view :right put-fn]]])
         [h/error-boundary
          [f/dashboard put-fn]]]]
       [h/error-boundary
        [stats/stats-text]]
       [h/error-boundary
        [upd/updater put-fn]]])))

(defn countries-page [put-fn]
  [:div.flex-container
   [loc/location-chart]])

(defn cal [put-fn]
  [:div.flex-container
   [cal/calendar-view put-fn]])

(defn load-progress [put-fn]
  (let [startup-progress (subscribe [:startup-progress])]
    (fn [put-fn]
      (let [startup-progress @startup-progress
            percent (Math/floor (* 100 startup-progress))]
        [:div.loader
         [:div.content
          [:h1 "starting meo v" (.getVersion (aget remote "app")) "..."]
          [:div.meter
           [:span {:style {:width (str percent "%")}}]]]]))))

(defn re-frame-ui [put-fn]
  (let [current-page (subscribe [:current-page])
        startup-progress (subscribe [:startup-progress])
        cfg (subscribe [:cfg])
        data-explorer (reaction (:data-explorer @cfg))]
    (fn [put-fn]
      (let [current-page @current-page
            startup-progress @startup-progress]
        (when-not @data-explorer
          (aset js/document "body" "style" "overflow" "hidden"))
        (if (= 1 startup-progress)
          [:div
           (case (:page current-page)
             :config [cfg/config put-fn]
             :countries [countries-page put-fn]
             :calendar [cal put-fn]
             :correlation [corr/scatter-matrix put-fn]
             :heatmap [hm/heatmap put-fn]
             :gallery [ic/gallery-page]
             :help [help/help put-fn]
             :empty [:div.flex-container]
             [main-page put-fn])
           (when @data-explorer
             [dex/data-explorer])]
          [load-progress put-fn])))))

(defn state-fn [put-fn]
  (reset! rfd/emit-atom put-fn)
  (rc/render [re-frame-ui put-fn] (.getElementById js/document "reframe"))
  {:observed rdb/app-db})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
