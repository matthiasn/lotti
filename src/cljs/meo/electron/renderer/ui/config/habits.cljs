(ns meo.electron.renderer.ui.config.habits
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error]]
            [meo.electron.renderer.helpers :as h]
            [clojure.string :as s]
            [reagent.core :as r]
            [moment]
            [meo.electron.renderer.graphql :as gql]
            [meo.common.utils.misc :as m]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.electron.renderer.ui.journal :as j]))

(defn lower-case [str]
  (if str (s/lower-case str) ""))

(defn gql-query [pvt search-text put-fn]
  (let [queries [[:habits_cfg
                  {:search-text search-text
                   :n           1000}]]
        query (gql/tabs-query queries false pvt)]
    (put-fn [:gql/query {:q        query
                         :id       :habits_cfg
                         :res-hash nil
                         :prio     11}])))

(defn habit-line [_habit local put-fn]
  (let [show-pvt (subscribe [:show-pvt])
        cfg (subscribe [:cfg])]
    (fn habit-line-render [habit local put-fn]
      (let [entry (:habit_entry habit)
            ts (:timestamp entry)
            text (eu/first-line entry)
            locale (:locale @cfg :en)
            date-str (h/localize-date (moment (or ts)) locale)
            sel (:selected @local)
            line-click (fn [_]
                         (swap! local assoc-in [:selected] ts)
                         (gql-query @show-pvt (str ts) put-fn))
            pvt (get-in habit [:habit_entry :habit :pvt])
            active (get-in habit [:habit_entry :habit :active])]
        [:tr {:key      ts
              :class    (when (= sel ts) "active")
              :on-click line-click}
         [:td date-str]
         [:td.habit text]
         [:td.completion
          (for [[i c] (m/idxd (reverse (take 10 (:completed habit))))]
            [:span.status {:class (when (:success c) "success")
                           :key   i}])]
         [:td [:i.fas {:class (if active "fa-toggle-on" "fa-toggle-off")}]]
         [:td [:i.fas {:class (if pvt "fa-toggle-on" "fa-toggle-off")}]]]))))

(defn habits [local put-fn]
  (let [pvt (subscribe [:show-pvt])
        input-fn (fn [ev]
                   (let [text (lower-case (h/target-val ev))]

                     (swap! local assoc-in [:search] text)))
        open-new (fn [x]
                   (let [ts (:timestamp x)]
                     (swap! local assoc-in [:selected] ts)
                     (gql-query @pvt (str ts) put-fn)))
        add-click (h/new-entry put-fn {:entry_type :habit
                                       :perm_tags  #{"#habit-cfg"}
                                       :tags       #{"#habit-cfg"}
                                       :habit      {:active true}}
                               open-new)
        gql-res (subscribe [:gql-res])
        habits-success (reaction (-> @gql-res :habits-success :data :habits_success))
        pvt (subscribe [:show-pvt])
        by-ts #(get-in % [:habit_entry :timestamp])
        by-text #(get-in % [:habit_entry :text])
        by-pvt #(get-in % [:habit_entry :habit :pvt])
        by-active #(get-in % [:habit_entry :habit :active])
        by-success #(->> % :completed (take 10) (filter :success) count)]
    (fn habits-render [local put-fn]
      (let [pvt @pvt
            search-text (:search @local)
            habits (filter #(or pvt (not (get-in % [:habit_entry :habit :pvt]))) @habits-success)
            search-match (fn [x] (s/includes? (eu/first-line (:habit_entry x)) (str search-text)))
            habits (filter search-match habits)
            sort-fn (get-in @local [:habits_cfg :sorted-by] by-ts)
            sort-click (fn [f]
                         (fn [_]
                           (if (= f sort-fn)
                             (swap! local update-in [:habits_cfg :reverse] not)
                             (swap! local assoc-in [:habits_cfg :sorted-by] f))))
            habits (sort-by sort-fn habits)
            habits (if (:reverse (:habits_cfg @local)) (reverse habits) habits)]
        [:div.col.habits
         [:h2 "Habits Editor"]
         [:div.input-line
          [:span.search
           [:i.far.fa-search]
           [:input {:on-change input-fn}]
           [:span.add {:on-click add-click}
            [:i.fas.fa-plus]]]]
         [:table.habit_cfg
          [:tbody
           [:tr
            [:th {:on-click (sort-click by-ts)} "Created"]
            [:th {:on-click (sort-click by-text)} "Habit"]
            [:th {:on-click (sort-click by-success)} "Success"]
            [:th {:on-click (sort-click by-active)} "active"]
            [:th {:on-click (sort-click by-pvt)} "private"]]
           (for [habit habits]
             ^{:key (:timestamp (:habit_entry habit))}
             [habit-line habit local put-fn])]]]))))

(defn habits-tab [tab-group _put-fn]
  (let [query-cfg (subscribe [:query-cfg])
        query-id (reaction (get-in @query-cfg [:tab-groups tab-group :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id :search-text]))
        local-cfg (reaction {:query-id    @query-id
                             :search-text @search-text
                             :tab-group   tab-group})]
    (fn tabs-render [_tab-group put-fn]
      [:div.tile-tabs
       [j/journal-view @local-cfg put-fn]])))

(defn habits-row [local put-fn]
  [:div.habit-cfg-row
   [h/error-boundary
    [habits local put-fn]]
   (when (:selected @local)
     [h/error-boundary
      [habits-tab :habits_cfg put-fn]])])
