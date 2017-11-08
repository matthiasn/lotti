(ns meo.electron.renderer.ui.grid
  (:require [reagent.core :as rc]
            [meo.electron.renderer.ui.journal :as j]
            [clojure.string :as s]
            [moment]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.search :as search]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.ui.entry.entry :as e]))

(defn fmt-ts [q]
  (let [ts (:timestamp q)]
    (.format (moment (js/parseInt ts)) "YY-MM-DD HH:mm")))

(defn tabs-header-view
  [tab-group put-fn]
  (let [query-cfg (subscribe [:query-cfg])]
    (fn tabs-header-view2-render
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
         [:div.tab-item.add
          {:on-click #(put-fn [:search/add {:tab-group tab-group}])}
          [:span "add"]]
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
                :on-click      #(put-fn [:search/set-active query-coord])
                :draggable     true
                :on-drag-start on-drag-start}
               [:span (str (or search-text q))
                [:span.fa.fa-times
                 {:on-click #(do (put-fn [:search/remove query-coord])
                                 (.stopPropagation %))}]]]))]]))))

(defn tabs-view
  [tab-group put-fn]
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
         [search/search-field-view query-id put-fn])
       (when @query-id
         [j/journal-view @local-cfg put-fn])])))
