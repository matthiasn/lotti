(ns meins.electron.renderer.ui.preferences.stories
  (:require ["moment" :as moment]
            [clojure.string :as s]
            [meins.electron.renderer.graphql :as gql]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.journal :as j]
            [meins.electron.renderer.ui.preferences.header :refer [header]]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [meins.common.utils.misc :as m]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [error info]]))

(defn gql-query [pvt search-text]
  (let [queries [[:stories_cfg
                  {:search-text search-text
                   :n           1000}]]
        query (gql/tabs-query queries false pvt)]
    (emit [:gql/query {:q        query
                         :id       :stories_cfg
                         :res-hash nil
                         :prio     11}])))

(defn story-row [_story _local]
  (let [show-pvt (subscribe [:show-pvt])
        cfg (subscribe [:cfg])]
    (fn story-row-render [story local]
      (let [ts (:timestamp story)
            sel (:selected @local)
            line-click (fn [_]
                         (swap! local assoc-in [:selected] ts)
                         (gql-query @show-pvt (str ts)))
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

(defn stories-list [local]
  (let [pvt (subscribe [:show-pvt])
        stories (subscribe [:stories])
        input-fn (fn [ev]
                   (let [text (m/lower-case (h/target-val ev))]
                     (swap! local assoc-in [:search] text)))
        open-new (fn [x]
                   (let [ts (:timestamp x)]
                     (swap! local assoc-in [:selected] ts)
                     (gql-query @pvt (str ts))))
        add-click (h/new-entry {:entry_type :story
                                       :perm_tags  #{"#story-cfg"}
                                       :tags       #{"#story-cfg"}
                                       :story_cfg  {:active true}} open-new)
        show-pvt (subscribe [:show-pvt])]
    (fn stories-list-render [local]
      (let [show-pvt @show-pvt
            search-text (:search @local "")
            search-match #(h/str-contains-lc? (:story_name %) (str search-text))
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
         [header "Stories Editor" input-fn search-text add-click]
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
             [story-row story local])]]]))))

(defn stories-tab [tab-group]
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

(defn stories [local]
  [:div.habit-cfg-row
   [h/error-boundary
    [stories-list local]]
   (when (:selected @local)
     [h/error-boundary
      [stories-tab :stories_cfg]])])
