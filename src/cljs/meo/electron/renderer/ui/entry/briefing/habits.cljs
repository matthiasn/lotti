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

(defn habit-line [_habit _tab-group put-fn]
  (let [query-cfg (subscribe [:query-cfg])
        query-id-left (reaction (get-in @query-cfg [:tab-groups :left :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id-left :search-text]))
        open-new (fn [x]
                   (put-fn [:search/add
                            {:tab-group :left
                             :query     (up/parse-search (:timestamp x))}]))]
    (fn habit-line-render [habit tab-group put-fn]
      (let [entry (:habit_entry habit)
            ts (:timestamp entry)
            text (eu/first-line entry)
            create-entry #(let [story (get-in entry [:story :timestamp])
                                f (h/new-entry put-fn {:primary_story story} open-new)
                                new-entry (f)]
                            (info entry)
                            (info new-entry))]
        [:tr {:key   ts
              :class (when (= (str ts) search-text) "selected")}
         [:td.completion
          (for [[i c] (m/idxd (reverse (take 5 (:completed habit))))]
            [:span.status {:class (when (:success c) "success")
                           :key   i}])]
         [:td.habit
          {:on-click (up/add-search ts tab-group put-fn)}
          text]
         [:td.start
          [:i.fas.fa-hourglass-start
           {:on-click create-entry}]]]))))

(defn waiting-habits
  "Renders table with open habits."
  [local _put-fn]
  (let [gql-res (subscribe [:gql-res])
        habits-success (reaction (-> @gql-res :habits-success :data :habits_success))
        pvt (subscribe [:show-pvt])
        filter-fn #(swap! local update-in [:all] not)]
    (fn waiting-habits-list-render [local put-fn]
      (let [local @local
            pvt @pvt
            habits (filter #(or (:all local)
                                (not (:success (first (:completed %)))))
                           @habits-success)
            habits (filter #(or pvt (not (get-in % [:habit_entry :habit :pvt]))) habits)
            habits (filter #(-> % :habit_entry :habit :active) habits)
            tab-group :briefing
            open-new (fn [x]
                       (put-fn [:search/add
                                {:tab-group :left
                                 :query     (up/parse-search (:timestamp x))}]))
            habit-default {:entry_type :habit
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
            [:th "Stuff I said I'd do."]
            [:th
             [:div.add-habit {:on-click new-habit}
              [:i.fas.fa-plus]]]]
           (for [habit habits]
             ^{:key (:timestamp (:habit_entry habit))}
             [habit-line habit tab-group put-fn])]]]))))
