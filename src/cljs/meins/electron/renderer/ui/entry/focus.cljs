(ns meins.electron.renderer.ui.entry.focus
  (:require [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [meins.electron.renderer.charts.data :as cd]
            [meins.electron.renderer.ui.charts.common :as cc]
            [meins.common.utils.misc :as u]
            [meins.electron.renderer.ui.entry.briefing.tasks :as tasks]
            [meins.electron.renderer.ui.entry.briefing.habits :as habits]
            [meins.electron.renderer.ui.entry.briefing.time :as time]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [reagent.core :as r]
            [react-event-timeline :as ret]
            [taoensso.timbre :refer-macros [info debug]]
            [moment]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.actions :as a]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [clojure.string :as s]
            [meins.electron.renderer.ui.entry.entry :as e]
            [meins.electron.renderer.ui.entry.briefing.calendar :as cal]
            [cljs.pprint :as pp]
            [meins.common.utils.parse :as up]
            [matthiasn.systems-toolbox.component :as st]
            [meins.electron.renderer.ui.ui-components :as uc]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.electron.renderer.ui.updater :as upd]
            [meins.electron.renderer.ui.grid :as g]
            [meins.electron.renderer.ui.menu :as menu]
            [meins.electron.renderer.ui.journal :as j]
            [meins.electron.renderer.graphql :as gql]))

(def timeline (r/adapt-react-class ret/Timeline))
(def timeline-event (r/adapt-react-class ret/TimelineEvent))

(defn entry-card [entry]
  (let [locale (subscribe [:locale])
        gql-res (subscribe [:gql-res2])
        left-entry (reaction (first (vals (get-in @gql-res [:left :res]))))]
    (fn [entry]
      (let [ts (:timestamp entry)
            linked-entries (set (:linked_entries_list @left-entry))
            status (cond
                     (-> entry :task :done) "completed"
                     (-> entry :task :closed) "rejected"
                     (:task entry) "open"
                     (:git_commit entry) "commit"
                     (:img_file entry) "img"
                     :default nil)
            status-cls (case status
                         "rejected" "fa-times red"
                         "completed" "fa-check green"
                         "open" "fa-check"
                         "commit" "fa-code-commit"
                         "img" "fa-image"
                         "fa-sticky-note")
            on-click (up/add-search2
                       {:tab-group    :right
                        :query-string ts} emit)
            cls (cond (= (:timestamp entry) (:timestamp @left-entry)) "green"
                      (contains? linked-entries (:timestamp entry)) "blue")]
        [timeline-event {:contentStyle {:padding 0
                                        :margin  0}
                         :bubbleStyle  {:border-color "#BBB"}
                         :icon         (r/as-element [:i.fas {:class status-cls}])}
         [:div.card {:on-click on-click
                     :class    cls}
          [:time (h/localize-datetime-full ts @locale)]
          [:h2 (eu/first-line entry)]
          (when (:task entry)
            [:div.task-status
             [:div status " task"]])
          (when-let [file (:img_file entry)]
            [:img {:src (h/thumbs-512 file)}])
          [e/git-commit entry]]]))))

(defn timeline-query [s pvt]
  (let [queries [[:timeline {:story s :n 1000}]]
        gql-query (gql/tabs-query queries false pvt)]
    (emit [:gql/query {:q        gql-query
                       :id       :timeline
                       :res-hash nil
                       :prio     3}])))

(defn timeline-column [tab-group]
  (let [gql-res (subscribe [:gql-res2])
        pvt (subscribe [:show-pvt])
        entries-list (reaction (get-in @gql-res [:timeline :res]))
        left-entry (reaction (first (vals (get-in @gql-res [:left :res]))))
        linked (reaction (->> (:linked @left-entry)
                              (filter #(not (:briefing %)))
                              (map (fn [x] [(:timestamp x) x]))
                              (into {})))
        combined (reaction (->> (merge @entries-list @linked)
                                vals
                                (sort-by :timestamp)
                                reverse))]
    (fn timeline-column-render [tab-group]
      (timeline-query (:primary_story @left-entry) @pvt)
      [:div.focus
       [timeline
        (for [entry @combined]
          ^{:key (:timestamp entry)}
          [entry-card entry])]])))

(defn tabs-view [tab-group]
  (let [query-cfg (subscribe [:query-cfg])
        query-id (reaction (get-in @query-cfg [:tab-groups tab-group :active]))
        story (reaction (get-in @query-cfg [:queries @query-id :story]))
        search-text (reaction (get-in @query-cfg [:queries @query-id :search-text]))
        local-cfg (reaction {:query-id    @query-id
                             :search-text @search-text
                             :tab-group   tab-group
                             :story       @story})]
    (fn tabs-render [tab-group]
      [:div.tile-tabs
       (when @query-id
         [j/journal-view @local-cfg])])))

(defn focus-page []
  (let [cfg (subscribe [:cfg])]
    (fn []
      [:div.flex-container
       [:div.grid
        [:div.focus-wrapper
         [h/error-boundary [menu/menu-view2]]
         [h/error-boundary [menu/busy-status]]
         [h/error-boundary [timeline-column :focus]]
         [:div.left
          [h/error-boundary [tabs-view :left]]]
         [:div.right
          [h/error-boundary [g/tabs-view :right]]]]]
       [h/error-boundary
        [upd/updater]]])))
