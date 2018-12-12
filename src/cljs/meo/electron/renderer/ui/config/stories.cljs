(ns meo.electron.renderer.ui.config.stories
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error]]
            [meo.electron.renderer.helpers :as h]
            [clojure.string :as s]
            [reagent.core :as r]
            [meo.electron.renderer.graphql :as gql]
            [meo.electron.renderer.ui.journal :as j]
            [moment]))

(defn lower-case [str]
  (if str (s/lower-case str) ""))

(defn gql-query [pvt search-text put-fn]
  (let [queries [[:stories_cfg
                  {:search-text search-text
                   :n           1000}]]
        query (gql/tabs-query queries false pvt)]
    (put-fn [:gql/query {:q        query
                         :id       :stories_cfg
                         :res-hash nil
                         :prio     11}])))

(defn story-row [_story local put-fn]
  (let [show-pvt (subscribe [:show-pvt])
        cfg (subscribe [:cfg])]
    (fn story-row-render [story local put-fn]
      (let [ts (:timestamp story)
            sel (:selected @local)
            line-click (fn [_]
                         (swap! local assoc-in [:selected] ts)
                         (gql-query @show-pvt (str ts) put-fn))
            locale (:locale @cfg :en)
            date-str (h/localize-date (moment (or ts)) locale)
            pvt (:pvt story)
            active (:active story)]
        [:tr {:key      ts
              :class    (when (= sel ts) "active")
              :on-click line-click}
         [:td date-str]
         [:td [:strong (:saga_name (:saga story))]]
         [:td [:strong (:story_name story)]]
         [:td [:i.fas {:class (if active "fa-toggle-on" "fa-toggle-off")}]]
         [:td [:i.fas {:class (if pvt "fa-toggle-on" "fa-toggle-off")}]]]))))

(defn stories-list [local put-fn]
  (let [pvt (subscribe [:show-pvt])
        stories (subscribe [:stories])
        input-fn (fn [ev]
                   (let [text (lower-case (h/target-val ev))]
                     (swap! local assoc-in [:stories-search] text)))
        open-new (fn [x]
                   (let [ts (:timestamp x)]
                     (swap! local assoc-in [:selected] ts)
                     (gql-query @pvt (str ts) put-fn)))
        add-click (h/new-entry put-fn {:entry_type :story
                                       :perm_tags  #{"#story-cfg"}
                                       :tags       #{"#story-cfg"}
                                       :story_cfg  {:active true}} open-new)
        show-pvt (subscribe [:show-pvt])]
    (fn stories-list-render [local put-fn]
      (let [show-pvt @show-pvt
            search-text (:stories-search @local)
            search-match (fn [x] (s/includes? (s/lower-case (str (:story_name x)))
                                              (s/lower-case (str search-text))))
            pvt-filter (fn [x] (if show-pvt true (not (:pvt x))))
            sort-fn (get-in @local [:stories_cfg :sorted-by])
            stories (->> (vals @stories)
                         (filter search-match)
                         (filter pvt-filter)
                         (sort-by sort-fn))
            stories (if (get-in @local [:stories_cfg :reverse])
                      (reverse stories)
                      stories)
            sort-click (fn [k]
                         (fn [_]
                           (if (= k sort-fn)
                             (swap! local update-in [:stories_cfg :reverse] not)
                             (swap! local assoc-in [:stories_cfg :sorted-by] k))))]
        [:div.col.habits.stories
         [:h2 "Stories Editor"]
         [:div.input-line
          [:span.search
           [:i.far.fa-search]
           [:input {:on-change input-fn
                    :value     search-text}]
           [:span.add {:on-click add-click}
            [:i.fas.fa-plus]]]]
         [:table.sagas-stories
          [:tbody
           [:tr
            [:th {:on-click (sort-click :timestamp)} "Created"]
            [:th {:on-click (sort-click #(get-in % [:saga :saga_name]))} "Saga"]
            [:th {:on-click (sort-click :story_name)} "Story"]
            [:th {:on-click (sort-click :active)} "Active"]
            [:th {:on-click (sort-click :pvt)} "Private"]]
           (for [story stories]
             ^{:key (:timestamp story)}
             [story-row story local put-fn])]]]))))

(defn stories-tab [tab-group _put-fn]
  (let [query-cfg (subscribe [:query-cfg])
        query-id (reaction (get-in @query-cfg [:tab-groups tab-group :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id :search-text]))
        local-cfg (reaction {:query-id    @query-id
                             :search-text @search-text
                             :tab-group   tab-group})]
    (fn tabs-render [_tab-group put-fn]
      [:div.tile-tabs
       [j/journal-view @local-cfg put-fn]])))

(defn stories [local put-fn]
  [:div.habit-cfg-row
   [h/error-boundary
    [stories-list local put-fn]]
   (when (:selected @local)
     [h/error-boundary
      [stories-tab :stories_cfg put-fn]])])
