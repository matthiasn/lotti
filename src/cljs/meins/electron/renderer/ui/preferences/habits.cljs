(ns meins.electron.renderer.ui.preferences.habits
  (:require ["moment" :as moment]
            [clojure.string :as s]
            [meins.common.utils.misc :as m]
            [meins.electron.renderer.graphql :as gql]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [meins.electron.renderer.ui.journal :as j]
            [meins.electron.renderer.ui.preferences.header :refer [header]]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [error info]]))

(defn gql-query [pvt search-text]
  (let [queries [[:habits_cfg
                  {:search-text search-text
                   :n           1000}]]
        query (gql/tabs-query queries false pvt)]
    (emit [:gql/query {:q        query
                       :id       :habits_cfg
                       :res-hash nil
                       :prio     11}])))

(defn habit-line [_habit _local]
  (let [show-pvt (subscribe [:show-pvt])
        cfg (subscribe [:cfg])]
    (fn habit-line-render [habit local]
      (let [entry (:habit_entry habit)
            ts (:timestamp entry)
            text (eu/first-line entry)
            locale (:locale @cfg :en)
            date-str (h/localize-date (moment (or ts)) locale)
            sel (:selected @local)
            line-click (fn [_]
                         (swap! local assoc-in [:selected] ts)
                         (gql-query @show-pvt (str ts)))
            pvt (get-in habit [:habit_entry :habit :pvt])
            active (get-in habit [:habit_entry :habit :active])]
        [:tr {:key      ts
              :class    (when (= sel ts) "active")
              :on-click line-click}
         [:td date-str]
         [:td.title text]
         [:td.completion
          (for [[i c] (m/idxd (reverse (take 10 (:completed habit))))]
            [:span.status {:class (when (:success c) "success")
                           :key   i}])]
         [:td.c [:i.fas {:class (if active "fa-toggle-on" "fa-toggle-off")}]]
         [:td.c [:i.fas {:class (if pvt "fa-toggle-on" "fa-toggle-off")}]]]))))

(defn habits [local]
  (let [pvt (subscribe [:show-pvt])
        input-fn (fn [ev]
                   (let [text (m/lower-case (h/target-val ev))]
                     (swap! local assoc-in [:search] text)))
        open-new (fn [x]
                   (let [ts (:timestamp x)]
                     (swap! local assoc-in [:selected] ts)
                     (gql-query @pvt (str ts))))
        add-click (h/new-entry {:entry_type :habit
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
    (fn habits-render [local]
      (let [pvt @pvt
            search-text (:search @local "")
            habits (filter #(or pvt (not (get-in % [:habit_entry :habit :pvt])))
                           @habits-success)
            search-match #(h/str-contains-lc?
                            (eu/first-line (:habit_entry %))
                            (str search-text))
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
         [header "Habits Editor" input-fn search-text add-click]
         [:table.habit_cfg
          [:tbody
           [:tr
            [:th {:on-click (sort-click by-ts)} "Created"]
            [:th {:on-click (sort-click by-text)} "Habit"]
            [:th {:on-click (sort-click by-success)} "Success"]
            [:th.c {:on-click (sort-click by-active)} "active"]
            [:th.c {:on-click (sort-click by-pvt)} "private"]]
           (for [habit habits]
             ^{:key (:timestamp (:habit_entry habit))}
             [habit-line habit local])]]]))))

(defn habits-tab [tab-group]
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

(defn habits-row [local]
  [:div.habit-cfg-row
   [h/error-boundary
    [habits local]]
   (when (:selected @local)
     [h/error-boundary
      [habits-tab :habits_cfg]])])
