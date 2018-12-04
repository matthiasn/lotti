(ns meo.electron.renderer.ui.config.sagas
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error]]
            [meo.electron.renderer.helpers :as h]
            [clojure.string :as s]
            [reagent.core :as r]
            [meo.electron.renderer.graphql :as gql]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.electron.renderer.ui.journal :as j]
            [moment]))

(defn lower-case [str]
  (if str (s/lower-case str) ""))

(defn gql-query [pvt search-text put-fn]
  (let [queries [[:sagas_cfg
                  {:search-text search-text
                   :n           1000}]]
        query (gql/tabs-query queries false pvt)]
    (put-fn [:gql/query {:q        query
                         :id       :sagas_cfg
                         :res-hash nil
                         :prio     11}])))

(defn saga-row [_saga local put-fn]
  (let [show-pvt (subscribe [:show-pvt])
        cfg (subscribe [:cfg])]
    (fn saga-row-render [saga local put-fn]
      (let [ts (:timestamp saga)
            sel (:selected @local)
            line-click (fn [_]
                         (swap! local assoc-in [:selected] ts)
                         (gql-query @show-pvt (str ts) put-fn))
            locale (:locale @cfg :en)
            date-str (h/localize-date (moment (or ts)) locale)
            pvt (:pvt saga)
            active (:active saga)]
        [:tr {:key      ts
              :class    (when (= sel ts) "active")
              :on-click line-click}
         [:td date-str]
         [:td [:strong (:saga_name saga)]]
         [:td [:i.fas {:class (if active "fa-toggle-on" "fa-toggle-off")}]]
         [:td [:i.fas {:class (if pvt "fa-toggle-on" "fa-toggle-off")}]]]))))

(defn sagas-list [local put-fn]
  (let [pvt (subscribe [:show-pvt])
        sagas (subscribe [:sagas])
        input-fn (fn [ev]
                   (let [text (lower-case (h/target-val ev))]

                     (swap! local assoc-in [:search] text)))
        open-new (fn [x]
                   (let [ts (:timestamp x)]
                     (swap! local assoc-in [:selected] ts)
                     (gql-query @pvt (str ts) put-fn)))
        add-click (h/new-entry put-fn {:entry_type :saga
                                       :perm_tags  #{"#saga-cfg"}
                                       :tags       #{"#saga-cfg"}
                                       :saga_cfg    {:active true}} open-new)
        show-pvt (subscribe [:show-pvt])]
    (fn sagas-list-render [local put-fn]
      (let [show-pvt @show-pvt
            sagas @sagas
            search-text (:search @local)
            search-match (fn [x] (s/includes? (s/lower-case (str (:saga_name (second x))))
                                              (s/lower-case (str search-text))))
            pvt-filter (fn [x] (if show-pvt true (not (:pvt (second x)))))
            sagas (filter search-match sagas)
            sagas (filter pvt-filter sagas)]
        [:div.col.habits.sagas
         [:h2 "Sagas Editor"]
         [:div.input-line
          [:span.search
           [:i.far.fa-search]
           [:input {:on-change input-fn}]
           [:span.add {:on-click add-click}
            [:i.fas.fa-plus]]]]
         [:table.sagas-stories
          [:tbody
           [:tr
            [:th "created"]
            [:th "saga"]
            [:th "active"]
            [:th "private"]]
           (for [saga (vals sagas)]
             ^{:key (:timestamp saga)}
             [saga-row saga local put-fn])]]]))))

(defn sagas-tab [tab-group _put-fn]
  (let [query-cfg (subscribe [:query-cfg])
        query-id (reaction (get-in @query-cfg [:tab-groups tab-group :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id :search-text]))
        local-cfg (reaction {:query-id    @query-id
                             :search-text @search-text
                             :tab-group   tab-group})]
    (fn tabs-render [_tab-group put-fn]
      [:div.tile-tabs
       [j/journal-view @local-cfg put-fn]])))

(defn sagas [local put-fn]
  [:div.habit-cfg-row
   [h/error-boundary
    [sagas-list local put-fn]]
   (when (:selected @local)
     [h/error-boundary
      [sagas-tab :sagas_cfg put-fn]])])
