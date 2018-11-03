(ns meo.electron.renderer.ui.entry.briefing.habits
  (:require [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info]]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.common.utils.parse :as up]
            [moment]
            [meo.electron.renderer.helpers :as h]
            [meo.common.utils.misc :as m]))

(defn habit-sorter
  "Sorts habits."
  [x y]
  (let [c (compare (or (get-in x [:habit :priority]) :X)
                   (or (get-in y [:habit :priority]) :X))]
    (if (not= c 0) c (compare (get-in y [:habit :points])
                              (get-in x [:habit :points])))))

(defn habit-line [_habit _tab-group _put-fn]
  (let [query-cfg (subscribe [:query-cfg])
        query-id-left (reaction (get-in @query-cfg [:tab-groups :left :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id-left :search-text]))]
    (fn habit-line-render [habit tab-group put-fn]
      (let [entry (:habit_entry habit)
            ts (:timestamp entry)
            text (eu/first-line entry)]
        [:tr {:key ts
              :on-click (up/add-search ts tab-group put-fn)
              :class    (when (= (str ts) search-text) "selected")}
         [:td.completion
          (for [[i c] (m/idxd (reverse (take 5 (:completed habit))))]
            [:span.status {:class (when (:success c) "success")
                           :key   i}])]
         [:td.habit text]]))))

(defn waiting-habits
  "Renders table with open entries, such as started tasks and open habits."
  [local _put-fn]
  (let [gql-res (subscribe [:gql-res])
        habits-success (reaction (-> @gql-res :habits-success :data :habits_success))
        filter-fn #(do
                     (info :click @local)
                     (swap! local update-in [:all] not))]
    (fn waiting-habits-list-render [local put-fn]
      (let [local @local
            habits (filter #(or (:all local)
                                (not (:success (first (:completed %)))))
                           @habits-success)
            tab-group :briefing
            open-new (fn [x]
                       (put-fn [:search/add
                                {:tab-group :left
                                 :query     (up/parse-search (:timestamp x))}]))
            habit-default {:entry-type :habit
                           :starred    true
                           :perm_tags  #{"#habit"}}
            new-habit (h/new-entry put-fn habit-default
                                   open-new)]
        [:div.waiting-habits
         [:table.habits
          [:tbody
           [:tr
            [:th {:on-click filter-fn}
             [:i.fas.filter
              {:class (if (:all local)
                        "fa-angle-double-down"
                        "fa-angle-double-up")}]]
            [:th "Stuff I said I'd do."
             [:div.add-habit {:on-click new-habit}
              [:i.fas.fa-plus]]]]
           (for [habit habits]
             ^{:key (:timestamp (:habit_entry habit))}
             [habit-line habit tab-group put-fn])]]]))))
