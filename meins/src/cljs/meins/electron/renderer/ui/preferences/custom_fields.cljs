(ns meins.electron.renderer.ui.preferences.custom-fields
  (:require [meins.electron.renderer.graphql :as gql]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.journal :as j]
            [meins.common.utils.misc :as m]
            [meins.electron.renderer.ui.preferences.assistants.custom-fields :as ac]
            [meins.electron.renderer.ui.preferences.header :refer [header]]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [error info]]))

(defn gql-query [pvt search-text]
  (let [queries [[:custom_field_cfg
                  {:search-text search-text
                   :n           1000}]]
        query (gql/tabs-query queries false pvt)]
    (emit [:gql/query {:q        query
                       :id       :custom_field_cfg
                       :res-hash nil
                       :prio     11}])))

(defn custom-fields-list [local]
  (let [stories (subscribe [:stories])
        backend-cfg (subscribe [:backend-cfg])
        pvt (subscribe [:show-pvt])
        select-item (fn [_tag cfg]
                      (let [ts (:timestamp cfg)
                            select-toggle #(when-not (= % ts) ts)]
                        (swap! local assoc-in [:new-field-input] "")
                        (swap! local update-in [:selected] select-toggle)
                        (gql-query @pvt (str (:timestamp cfg)))))
        cfg (reaction (:custom-fields @backend-cfg))
        custom-fields (reaction (sort-by #(m/lower-case (first %)) @cfg))
        input-fn (fn [ev]
                   (let [text (m/lower-case (h/target-val ev))]
                     (swap! local assoc-in [:search] text)))
        open-new (fn [x]
                   (let [ts (:timestamp x)]
                     (swap! local assoc-in [:selected] ts)
                     (gql-query @pvt (str ts))))
        add-click (h/new-entry {:entry_type       :custom-field-cfg
                                :perm_tags        #{"#custom-field-cfg"}
                                :tags             #{"#custom-field-cfg"}
                                :custom_field_cfg {:active true}}
                               open-new)]
    (fn custom-fields-list-render [local]
      (let [stories @stories
            search-text (:search @local "")
            item-filter #(h/str-contains-lc? (first %) search-text)
            items (filter item-filter @custom-fields)
            sel (:selected @local)
            items (if @pvt
                    items
                    (filter #(not (get-in % [1 :pvt])) items))]
        [:div.col.custom-fields
         [header "Custom Fields" input-fn search-text add-click]
         [:div.cfg-items
          (for [[tag cfg] items]
            (let [ds (:default-story cfg)
                  ts (:timestamp cfg)]
              ^{:key tag}
              [:div.custom-field
               {:on-click #(select-item tag cfg)
                :class    (when (= sel ts) "active")}
               [:div.story (get-in stories [ds :story_name])]
               [:h3 tag]
               [:ul
                (for [[k v] (:fields cfg)]
                  ^{:key (str tag k)}
                  [:li (:label v)])]]))]
         [ac/assistant items]]))))


(defn custom-field-tab [tab-group]
  (let [query-cfg (subscribe [:query-cfg])
        query-id (reaction (get-in @query-cfg [:tab-groups tab-group :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id :search-text]))
        local-cfg (reaction {:query-id    @query-id
                             :search-text @search-text
                             :show-more   false
                             :tab-group   tab-group})]
    (fn tabs-render [_tab-group]
      [:div.tile-tabs
       [j/journal-view @local-cfg]])))
