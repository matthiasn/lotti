(ns meins.electron.renderer.ui.focus
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
            [react-horizontal-timeline :as rht]
            [meins.common.utils.parse :as up]
            [matthiasn.systems-toolbox.component :as st]
            [meins.electron.renderer.ui.ui-components :as uc]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.electron.renderer.ui.updater :as upd]
            [meins.electron.renderer.ui.grid :as g]
            [meins.electron.renderer.ui.menu :as menu]
            [meins.electron.renderer.ui.journal :as j]
            [meins.electron.renderer.graphql :as gql]
            [meins.electron.renderer.ui.stats :as stats]))

(def timeline (r/adapt-react-class ret/Timeline))
(def timeline-event (r/adapt-react-class ret/TimelineEvent))

(def horizontal-timeline (r/adapt-react-class (aget rht "default")))

(defn entry-card [entry local]
  (let [locale (subscribe [:locale])
        gql-res (subscribe [:gql-res2])
        left-entry (reaction (first (vals (get-in @gql-res [:left :res]))))]
    (fn [entry local]
      (let [ts (:timestamp entry)
            linked-entries (set (:linked_entries_list @left-entry))
            status (cond
                     (-> entry :task :done) "completed"
                     (-> entry :task :closed) "rejected"
                     (:task entry) "open"
                     (:comment_for entry) "comment"
                     (:git_commit entry) "commit"
                     (:img_file entry) "img"
                     :default nil)
            status-cls (case status
                         "rejected" "fa-times red"
                         "comment" "fa-comment"
                         "completed" "fa-check green"
                         "open" "fa-check"
                         "commit" "fa-code-commit"
                         "img" "fa-image"
                         "fa-sticky-note")
            on-click (fn [ev]
                       (let [el (.getElementById js/document (str ":left" ts))]
                         (if el
                           (.scrollIntoView el (clj->js {:behavior "smooth"}))
                           ((up/add-search2
                              {:tab-group    :right
                               :query-string ts} emit)))))
            cls (cond (= (:timestamp entry) (:timestamp @left-entry)) "green"
                      (contains? linked-entries (:timestamp entry)) "blue")
            selected-day (= (:day @local) (h/ymd ts))]
        [timeline-event {:contentStyle {:padding 0
                                        :margin  0}
                         :bubbleStyle  {:border-color "#BBB"}
                         :icon         (r/as-element [:i.fas {:class status-cls}])}
         [:div.card {:on-click on-click
                     :class    (str cls " " (when selected-day "selected-day")
                                    " " (h/ymd ts))}
          [:time (h/localize-datetime-full ts @locale)]
          [:h2 (eu/first-line entry)]
          (when (:task entry)
            [:div.task-status
             [:div status " task"]])
          (when-let [file (:img_file entry)]
            [:img {:src (h/thumbs-512 file)}])
          [e/git-commit entry]]]))))

(defn timeline-query [tab-group s pvt]
  (let [queries [[:timeline {:story s :n 100}]]
        gql-query (gql/tabs-query queries false pvt)]
    (emit [:gql/query {:q        gql-query
                       :id       tab-group
                       :res-hash nil
                       :prio     3}])))

(defn timeline-column [tab-group local]
  (let [gql-res (subscribe [:gql-res2])
        pvt (subscribe [:show-pvt])
        entries-list (reaction (get-in @gql-res [tab-group :res]))
        left-entry (reaction (first (vals (get-in @gql-res [:left :res]))))
        linked (reaction (->> (:linked @left-entry)
                              (filter #(not (:briefing %)))
                              (map (fn [x] [(:timestamp x) x]))
                              (into {})))
        comments     (reaction (->> (:comments @left-entry)
                                    (map (fn [x] [(:timestamp x) x]))
                                    (into {})))
        combined (reaction (->> (merge @entries-list @linked @comments)
                                vals
                                (sort-by :timestamp)
                                reverse))
        did-mount (fn [_props] (timeline-query tab-group (:primary_story @left-entry) @pvt))
        will-unmount #(emit [:search/remove {:query-id  tab-group
                                             :tab-group tab-group}])]
    (r/create-class
      {:component-did-mount    did-mount
       :component-will-unmount will-unmount
       :reagent-render         (fn [_props]
                                 [:div.focus
                                  [timeline
                                   (for [entry @combined]
                                     ^{:key (:timestamp entry)}
                                     [entry-card entry local])]])})))

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


(defn timeline-view [local]
  (let [gql-res      (subscribe [:gql-res2])
        entries-list (reaction (get-in @gql-res [:focus :res]))
        left-entry   (reaction (first (vals (get-in @gql-res [:left :res]))))
        linked       (reaction (->> (:linked @left-entry)
                                    (filter #(not (:briefing %)))
                                    (map (fn [x] [(:timestamp x) x]))
                                    (into {})))
        comments     (reaction (->> (:comments @left-entry)
                                    (map (fn [x] [(:timestamp x) x]))
                                    (into {})))
        combined     (reaction (->> (merge @entries-list @linked @comments)
                                    vals
                                    (sort-by :timestamp)
                                    (map :timestamp)
                                    (map h/ymd)
                                    distinct))
        click        (fn [i]
                       (let [day (nth @combined i)]
                         (swap! local assoc :tl-idx i)
                         (swap! local assoc :day day)
                         (when-let [el  (aget (.getElementsByClassName js/document day) 0)]
                           (.scrollIntoView el (clj->js {:behavior "smooth"}))) ))]
    (fn [_local]
      [:div.post-mortem-timeline
       [horizontal-timeline
        {:values      @combined
         :index       (:tl-idx @local)
         :indexClick  click
         :linePadding 60}]])))

(defn focus-page []
  (let [cfg (subscribe [:cfg])
        local (r/atom {:tl-idx 0})]
    (fn []
      [:div.flex-container
       [:div.grid
        [:div.focus-wrapper
         [h/error-boundary [menu/menu-view2]]
         [h/error-boundary [menu/busy-status]]
         [:div.timeline
          [h/error-boundary [timeline-view local]]]
         [:div.left
          [h/error-boundary [tabs-view :left]]]
         [h/error-boundary [timeline-column :focus local]]
         [:div.right
          [h/error-boundary [g/tabs-view :right]]]]]
       [h/error-boundary
        [stats/stats-text]]
       [h/error-boundary
        [upd/updater]]])))
