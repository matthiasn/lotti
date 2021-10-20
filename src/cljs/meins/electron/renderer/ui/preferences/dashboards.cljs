(ns meins.electron.renderer.ui.preferences.dashboards
  (:require ["moment" :as moment]
            [clojure.string :as s]
            [meins.electron.renderer.graphql :as gql]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [meins.electron.renderer.ui.journal :as j]
            [meins.common.utils.misc :as m]
            [meins.electron.renderer.ui.preferences.header :refer [header]]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [error info]]))

(defn gql-query [pvt search-text]
  (let [queries [[:dashboards_cfg
                  {:search-text search-text
                   :n           1000}]]
        query (gql/tabs-query queries false pvt)]
    (emit [:gql/query {:q        query
                       :id       :dashboards_cfg
                       :res-hash nil
                       :prio     11}])))

(defn dashboard-line [_habit _local]
  (let [show-pvt (subscribe [:show-pvt])
        cfg (subscribe [:cfg])]
    (fn habit-line-render [entry local]
      (let [ts (:timestamp entry)
            text (eu/first-line entry)
            text (or (when (seq text)
                       text)
                     "YOUR DASHBOARD DESCRIPTION HERE")
            locale (:locale @cfg :en)
            date-str (h/localize-date (moment (or ts)) locale)
            sel (:selected @local)
            line-click (fn [_]
                         (swap! local assoc-in [:selected] ts)
                         (gql-query @show-pvt (str ts)))
            pvt (get-in entry [:dashboard_cfg :pvt])
            active (get-in entry [:dashboard_cfg :active])]
        [:tr {:key      ts
              :class    (when (= sel ts) "active")
              :on-click line-click}
         [:td date-str]
         [:td.habit text]
         [:td.c [:i.fas {:class (if active "fa-toggle-on" "fa-toggle-off")}]]
         [:td.c [:i.fas {:class (if pvt "fa-toggle-on" "fa-toggle-off")}]]]))))

(defn dashboards [local]
  (let [pvt (subscribe [:show-pvt])
        input-fn (fn [ev]
                   (let [text (m/lower-case (h/target-val ev))]
                     (swap! local assoc-in [:search] text)))
        open-new (fn [x]
                   (let [ts (:timestamp x)]
                     (swap! local assoc-in [:selected] ts)
                     (gql-query @pvt (str ts))))
        add-click (h/new-entry {:entry_type    :dashboard-cfg
                                :perm_tags     #{"#dashboard-cfg"}
                                :tags          #{"#dashboard-cfg"}
                                :dashboard_cfg {:active true}}
                               open-new)
        gql-res2 (subscribe [:gql-res2])
        pvt (subscribe [:show-pvt])
        by-ts #(get-in % [:timestamp])
        by-text #(get-in % [:text])
        by-pvt #(get-in % [:dashboard_cfg :pvt])
        by-active #(get-in % [:dashboard_cfg :active])]
    (fn dashboards-render [local]
      (let [pvt @pvt
            search-text (:search @local "")
            sort-fn (get-in @local [:dashboards_cfg :sorted-by] by-ts)
            sort-click (fn [f]
                         (fn [_]
                           (if (= f sort-fn)
                             (swap! local update-in [:dashboards_cfg :reverse] not)
                             (swap! local assoc-in [:dashboards_cfg :sorted-by] f))))
            pvt-filter (fn [x] (if pvt true (not (get-in x [1 :dashboard_cfg :pvt]))))
            search-match #(h/str-contains-lc?
                            (eu/first-line (second %))
                            (str search-text))
            dashboards (->> @gql-res2
                            :dashboard_cfg
                            :res
                            (filter pvt-filter)
                            (filter search-match))]
        [:div.col.habits
         [header "Dashboards Editor" input-fn search-text add-click]
         [:table.habit_cfg
          [:tbody
           [:tr
            [:th {:on-click (sort-click by-ts)} "Created"]
            [:th {:on-click (sort-click by-text)} "Dashboard"]
            [:th {:on-click (sort-click by-active)} "active"]
            [:th {:on-click (sort-click by-pvt)} "private"]]
           (for [dashboard (vals dashboards)]
             ^{:key (:timestamp dashboard)}
             [dashboard-line dashboard local])]]]))))

(defn dashboards-tab [tab-group]
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

(defn dashboards-row [local]
  [:div.dashboards-cfg
   [:div.habit-cfg-row
    [h/error-boundary
     [dashboards local emit]]
    (when (:selected @local)
      [h/error-boundary
       [dashboards-tab :dashboards_cfg emit]])]])
