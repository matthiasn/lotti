(ns meo.electron.renderer.ui.grid
  (:require [reagent.core :as rc]
            [meo.electron.renderer.ui.journal :as j]
            [clojure.string :as s]
            [moment]
            [taoensso.timbre :refer [info error debug]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.search :as search]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.ui.entry.entry :as e]
            [meo.electron.renderer.ui.entry.briefing.calendar :as cal]
            [meo.electron.renderer.ui.entry.briefing :as b]
            [meo.electron.renderer.ui.charts.common :as cc]))

(defn fmt-ts [q]
  (let [ts (:timestamp q)]
    (.format (moment (js/parseInt ts)) "YY-MM-DD HH:mm")))

(defn tabs-header-view [tab-group put-fn]
  (let [query-cfg (subscribe [:query-cfg])
        gql-res (subscribe [:gql-res2])
        first-res (reaction (first (vals (get-in @gql-res [tab-group :res]))))]
    (fn tabs-header-view-render
      [tab-group put-fn]
      (let [query-config @query-cfg
            queries (-> query-config :tab-groups tab-group :all)
            active-query (-> query-config :tab-groups tab-group :active)
            on-drop #(let [dragged (:dragged query-config)]
                       (when (not= tab-group (:tab-group dragged))
                         (put-fn [:search/move-tab {:dragged dragged :to tab-group}]))
                       (.preventDefault %))]
        [:div.tabs-header {:on-drop       on-drop
                           :on-drag-over  h/prevent-default
                           :on-drag-enter h/prevent-default}
         [:div.tab-item.add-tab
          {:on-click #(put-fn [:search/add {:tab-group tab-group}])
           :class    (when (zero? (count queries))
                       "full")}
          (when (zero? (count queries))
            "add tab")
          [:span.fa.fa-plus]]
         (when (> (count queries) 2)
           [:div.tab-item.close-all
            {:on-click #(put-fn [:search/close-all {:tab-group tab-group}])}
            [:span (count queries) [:span.fa.fa-times]]])
         [:div.tab-items
          (for [q queries]
            (let [query (get-in query-config [:queries q])
                  search-text (s/trim (str (:search-text query)))
                  search-text (cond
                                (empty? search-text) "empty"
                                (:timestamp query) (fmt-ts query)
                                :else search-text)
                  query-coord {:query-id q :tab-group tab-group}
                  on-drag-start #(put-fn [:search/set-dragged query-coord])]
              ^{:key (str "tab-header" q)}
              [:div.tab-item
               {:class         (when (= active-query q) "active")
                :style         {:background-color (cc/item-color search-text)}
                :on-click      #(put-fn [:search/set-active query-coord])
                :draggable     true
                :on-drag-start on-drag-start}
               [:span.fa.fa-times
                {:style {:color (cc/item-color search-text "dark")}
                 :on-click #(do (put-fn [:search/remove query-coord])
                                (.stopPropagation %))}]]))]]))))

(defn tabs-view [tab-group put-fn]
  (let [query-cfg (subscribe [:query-cfg])
        query-id (reaction (get-in @query-cfg [:tab-groups tab-group :active]))
        story (reaction (get-in @query-cfg [:queries @query-id :story]))
        search-text (reaction (get-in @query-cfg [:queries @query-id :search-text]))
        local-cfg (reaction {:query-id    @query-id
                             :search-text @search-text
                             :tab-group   tab-group
                             :story       @story})]
    (fn tabs-render [tab-group put-fn]
      [:div.tile-tabs
       [tabs-header-view tab-group put-fn]
       (when @query-id
         ^{:key @query-id}
         [search/search-field-view tab-group query-id put-fn])
       (when @query-id
         [j/journal-view @local-cfg put-fn])])))
