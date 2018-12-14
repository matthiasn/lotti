(ns meo.electron.renderer.ui.config.custom-fields
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error]]
            [meo.electron.renderer.helpers :as h]
            [clojure.string :as s]
            [reagent.core :as r]
            [meo.electron.renderer.graphql :as gql]
            [meo.electron.renderer.ui.journal :as j]
            [meo.common.utils.parse :as up]))

(defn lower-case [str]
  (if str (s/lower-case str) ""))

(defn gql-query [pvt search-text put-fn]
  (let [queries [[:custom_field_cfg
                  {:search-text search-text
                   :n           1000}]]
        query (gql/tabs-query queries false pvt)]
    (put-fn [:gql/query {:q        query
                         :id       :custom_field_cfg
                         :res-hash nil
                         :prio     11}])))

(defn custom-fields-list [local put-fn]
  (let [stories (subscribe [:stories])
        backend-cfg (subscribe [:backend-cfg])
        pvt (subscribe [:show-pvt])
        select-item (fn [tag cfg]
                      (let [ts (:timestamp cfg)
                            select-toggle #(when-not (= % ts) ts)]
                        (swap! local assoc-in [:new-field-input] "")
                        (swap! local update-in [:selected] select-toggle)
                        (gql-query @pvt (str (:timestamp cfg)) put-fn)))
        cfg (reaction (:custom-fields @backend-cfg))
        custom-fields (reaction (sort-by #(lower-case (first %)) @cfg))
        input-fn (fn [ev]
                   (let [text (lower-case (h/target-val ev))]
                     (swap! local assoc-in [:search] text)))
        open-new (fn [x]
                   (let [ts (:timestamp x)]
                     (swap! local assoc-in [:selected] ts)
                     (gql-query @pvt (str ts) put-fn)))
        add-click (h/new-entry put-fn {:entry_type :custom-field-cfg
                                       :perm_tags  #{"#custom-field-cfg"}
                                       :tags       #{"#custom-field-cfg"}} open-new)]
    (fn custom-fields-list-render [local put-fn]
      (let [stories @stories
            text (:search @local "")
            item-filter #(h/str-contains-lc? (first %) text)
            items (filter item-filter @custom-fields)
            sel (:selected @local)
            items (if @pvt
                    items
                    (filter #(not (get-in % [1 :pvt])) items))]
        [:div.col.custom-fields
         [:h2 "Custom Fields Editor"]
         [:div.input-line
          [:span.search
           [:i.far.fa-search]
           [:input {:on-change input-fn}]
           [:span.add {:on-click add-click}
            [:i.fas.fa-plus]]]]
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
                  [:li (:label v)])]]))]]))))


(defn custom-field-tab [tab-group _put-fn]
  (let [query-cfg (subscribe [:query-cfg])
        query-id (reaction (get-in @query-cfg [:tab-groups tab-group :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id :search-text]))
        local-cfg (reaction {:query-id    @query-id
                             :search-text @search-text
                             :tab-group   tab-group})]
    (fn tabs-render [_tab-group put-fn]
      [:div.tile-tabs
       [j/journal-view @local-cfg put-fn]])))
