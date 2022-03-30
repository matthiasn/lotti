(ns meins.electron.renderer.ui.grid
  (:require ["moment" :as moment]
            ["tinycolor2" :as tinycolor]
            [clojure.string :as s]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.charts.common :as cc]
            [meins.electron.renderer.ui.journal :as j]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.search :as search]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as rc]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug error info]]))

(defn fmt-ts [q]
  (let [ts (:timestamp q)]
    (.format (moment (js/parseInt ts)) "YY-MM-DD HH:mm")))

(defn tabs-header-view [_tab-group]
  (let [query-cfg (subscribe [:query-cfg])]
    (fn tabs-header-view-render [tab-group]
      (let [query-config @query-cfg
            queries (-> query-config :tab-groups tab-group :all)
            active-query (-> query-config :tab-groups tab-group :active)
            on-drop #(let [dragged (:dragged query-config)]
                       (when (not= tab-group (:tab-group dragged))
                         (emit [:search/move-tab {:dragged dragged :to tab-group}]))
                       (.preventDefault %))
            queries (map (fn [q]
                           [q (get-in query-config [:queries q])])
                         queries)]
        [:div.tabs-header {:on-drop       on-drop
                           :on-drag-over  h/prevent-default
                           :on-drag-enter h/prevent-default}
         [:div.tab-item.add-tab
          {:on-click #(emit [:search/add {:tab-group tab-group}])
           :class    (when (zero? (count queries))
                       "full")}
          (when (zero? (count queries))
            "add tab")
          [:span.fa.fa-plus]]
         (when (> (count queries) 2)
           [:div.tab-item.close-all
            {:on-click #(emit [:search/close-all {:tab-group tab-group}])}
            [:span (count queries)]
            [:i.fas.fa-times]])
         [:div.tab-items
          (for [[q query] (sort-by #(:story-name (second %)) queries)]
            (let [search-text (s/trim (str (:search-text query)))
                  search-text (cond
                                (:story-name query) (:story-name query)
                                (empty? search-text) "empty"
                                (:timestamp query) (fmt-ts query)
                                :else search-text)
                  query-coord {:query-id q :tab-group tab-group}
                  on-drag-start #(emit [:search/set-dragged query-coord])
                  tooltip-text (:first-line query)
                  color (cc/item-color search-text)
                  active (= active-query q)
                  complement (when active (.complement (new tinycolor color)))]
              ^{:key (str "tab-header" q)}
              [:div.tooltip
               [:div.tab-item
                {:class         (when active "active")
                 :style         {:background-color color
                                 :border-bottom-color complement}
                 :on-click      #(emit [:search/set-active query-coord])
                 :draggable     true
                 :on-drag-start on-drag-start}
                [:span.fa.fa-times
                 {:style    {:color (cc/item-color search-text "dark")}
                  :on-click #(do (emit [:search/remove query-coord])
                                 (.stopPropagation %))}]]
               (when (seq tooltip-text)
                 [:div.tooltiptext
                  [:h4 tooltip-text]])]))]]))))

(defn tabs-view [tab-group]
  (let [query-cfg (subscribe [:query-cfg])
        query-id (reaction (get-in @query-cfg [:tab-groups tab-group :active]))
        story (reaction (get-in @query-cfg [:queries @query-id :story]))
        search-text (reaction (get-in @query-cfg [:queries @query-id :search-text]))
        local-cfg (reaction {:query-id    @query-id
                             :search-text @search-text
                             :tab-group   tab-group
                             :show-more   true
                             :story       @story})]
    (fn tabs-render [tab-group]
      [:div.tile-tabs
       [tabs-header-view tab-group]
       (when @query-id
         ^{:key @query-id}
         [search/search-field-view tab-group query-id])
       (when @query-id
         [j/journal-view @local-cfg])])))
