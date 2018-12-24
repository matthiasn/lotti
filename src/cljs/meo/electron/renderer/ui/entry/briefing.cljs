(ns meo.electron.renderer.ui.entry.briefing
  (:require [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.charts.data :as cd]
            [meo.electron.renderer.ui.charts.common :as cc]
            [meo.common.utils.misc :as u]
            [meo.electron.renderer.ui.entry.briefing.tasks :as tasks]
            [meo.electron.renderer.ui.entry.briefing.habits :as habits]
            [meo.electron.renderer.ui.entry.briefing.time :as time]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [reagent.core :as r]
            [taoensso.timbre :refer-macros [info debug]]
            [moment]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.entry.actions :as a]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [clojure.string :as s]
            [meo.electron.renderer.ui.entry.entry :as e]
            [meo.electron.renderer.ui.entry.briefing.calendar :as cal]
            [cljs.pprint :as pp]
            [meo.common.utils.parse :as up]
            [matthiasn.systems-toolbox.component :as st]
            [meo.electron.renderer.ui.ui-components :as uc]))

(defn planned-actual [entry]
  (let [chart-data (subscribe [:chart-data])
        sagas (subscribe [:sagas])
        y-scale 0.0045]
    (fn [entry]
      (let [{:keys [pomodoro-stats]} @chart-data
            day (-> entry :briefing :day)
            day-stats (get pomodoro-stats day)
            allocation (-> entry :briefing :time-allocation)
            sagas @sagas
            actual-times (:time-by-saga day-stats)
            remaining (cd/remaining-times actual-times allocation)
            rect (fn [entity x v y]
                   (let [h (* y-scale v)
                         x (inc (* y-scale x))
                         entity-name (or (:saga-name (get sagas entity)) "none")]
                     ^{:key (str entity)}
                     [:rect {:fill   (cc/item-color entity-name)
                             :y      y
                             :x      x
                             :width  h
                             :height 9}]))
            legend (fn [text x y]
                     [:text {:x           x
                             :y           y
                             :stroke      "none"
                             :fill        "#333"
                             :text-anchor :left
                             :style       {:font-size 7}}
                      text])]
        (when (seq allocation)
          [:svg.planned-actual
           {:shape-rendering "crispEdges"
            :style           {:height "41px"}}
           [:g
            [:line {:x1           1
                    :x2           260
                    :y1           38
                    :y2           38
                    :stroke-width 0.5
                    :stroke       "#333"}]
            (for [h (range 16)]
              (let [x (inc (* y-scale h 60 60))
                    stroke-w (if (zero? (mod h 3)) 1.5 0.5)]
                ^{:key h}
                [:line {:x1           x
                        :x2           x
                        :y1           36
                        :y2           40.5
                        :stroke-width stroke-w
                        :stroke       "#333"}]))
            (for [[entity {:keys [x v]}] (cd/time-by-entity-stacked allocation)]
              (rect entity x v 3))
            (for [[entity {:keys [x v]}] (cd/time-by-entity-stacked actual-times)]
              (rect entity x v 14))
            (for [[entity {:keys [x v]}] (cd/time-by-entity-stacked remaining)]
              (rect entity x v 25))
            [legend "allocation" 3 10]
            [legend "actual" 3 21]
            [legend "remaining" 3 32]]])))))

(defn sagas-filter [local]
  (let [sagas (subscribe [:sagas])
        all #(swap! local assoc-in [:selected-set] (set (keys @sagas)))
        none #(swap! local assoc-in [:selected-set] #{})]
    (fn sagas-filter-render [local]
      (let [local-deref @local
            sorted (sort-by #(s/lower-case (or (:saga_name (second %)) "")) @sagas)]
        [:div.saga-filter
         [:div.toggle-visible
          {:on-click #(swap! local update-in [:show-filter] not)}
          [:i.fas {:style {:margin-left  0
                           :margin-right 4}
                   :class (if (:show-filter @local)
                            "fa-chevron-square-up"
                            "fa-chevron-square-down")}]
          "filter"]
         (when (:show-filter @local)
           (let [elem (r/dom-node (r/current-component))
                 handler #(when-not (.contains elem (.-target %))
                            (swap! local dissoc :show-filter))]
             (.addEventListener js/document "click" handler))
           [:div.items
            [:div.controls
             [:div {:on-click all} "select all"]
             [:div {:on-click none} "clear"]]
            (for [[ts saga] sorted]
              (let [selected? (contains? (:selected-set local-deref) ts)
                    toggle #(let [op (if selected? disj conj)]
                              (swap! local update-in [:selected-set] op ts))]
                ^{:key ts}
                [:div.item {:class    (when selected? "selected")
                            :on-click toggle}
                 [uc/switch2 {:v selected?}]
                 (s/trim (:saga_name saga))]))])]))))

(defn add-task [ts]
  (let [open-new (fn [x]
                   (emit
                     [:cmd/schedule-new
                      {:message [:search/add
                                 {:tab-group :left
                                  :query     (up/parse-search (:timestamp x))}]
                       :timeout 100}]))]
    (fn add-task-render [ts]
      (let [new-task (h/new-entry {:linked_entries #{ts}
                                   :starred        true
                                   :perm_tags      #{"#task"}}
                                  open-new)]
        [:div.add-task
         [:div.toggle-visible
          {:on-click #(new-task)}
          "task"
          [:i.fas.fa-plus-square]]]))))

(defn all-entries-for-day []
  (let [cal-day (subscribe [:cal-day])
        click #(emit [:search/add
                      {:tab-group :left
                       :query     (up/parse-search @cal-day)}])]
    (fn []
      (let []
        [:div.add-task
         [:div.toggle-visible
          {:on-click click}
          "show all"
          [:i.fas.fa-chevron-square-right]]]))))

(defn briefing-view [local-cfg]
  (let [gql-res (subscribe [:gql-res])
        briefing (reaction (:briefing (:data (:briefing @gql-res))))
        day-stats (reaction (:logged_time (:data (:logged-by-day @gql-res))))
        cfg (subscribe [:cfg])
        local (r/atom {:filter                  :all
                       :outstanding-time-filter true
                       :selected-set            #{}
                       :show-filter             false
                       :show-points             false
                       :on-hold                 false})
        pvt (subscribe [:show-pvt])]
    (h/to-day (h/ymd (st/now)) pvt)
    (fn briefing-render [local-cfg]
      (let [ts (:timestamp @briefing)
            excluded (:excluded (:briefing @cfg))
            logged-s (->> @day-stats
                          :by_ts
                          (filter #(not (contains? excluded
                                                   (-> %
                                                       :story
                                                       :linked-saga
                                                       :timestamp))))
                          (map :summed)
                          (apply +))
            dur (u/duration-string logged-s)
            n (count (:by_ts @day-stats))
            drop-fn (a/drop-on-briefing @briefing cfg emit)]
        [:div.briefing {:on-drop       drop-fn
                        :on-drag-over  h/prevent-default
                        :on-drag-enter h/prevent-default}
         [:div.briefing-header
          [h/error-boundary
           [all-entries-for-day]]
          [h/error-boundary
           [sagas-filter local]]
          [h/error-boundary
           [add-task ts]]]
         [:div.scroll
          [h/error-boundary
           [tasks/started-tasks local local-cfg emit]]
          [h/error-boundary
           [tasks/open-linked-tasks local local-cfg emit]]
          [:div.entry-with-comments
           [:div.entry
            [:div.summary
             [:div
              "Tasks: " [:strong (:tasks_cnt @day-stats)] " created | "
              [:strong (:done_tasks_cnt @day-stats)] " done | "
              [:strong (:closed_tasks_cnt @day-stats)] " closed | Words: "
              [:strong (or (:word_count @day-stats) 0)]]
             [:div
              (when (seq dur)
                [:span
                 " Logged: " [:strong dur] " in " n " entries."])]]]
           [:div.comments
            (for [comment (:comments @briefing)]
              ^{:key (str "c" comment)}
              [e/journal-entry comment emit local-cfg])]]
          [h/error-boundary
           [tasks/open-tasks local local-cfg]]]]))))

(defn briefing-column-view
  [tab-group]
  (let [query-cfg (subscribe [:query-cfg])
        query-id (reaction (get-in @query-cfg [:tab-groups tab-group :active]))
        story (reaction (get-in @query-cfg [:queries @query-id :story]))
        search-text (reaction (get-in @query-cfg [:queries @query-id :search-text]))
        local-cfg (reaction {:query-id    @query-id
                             :search-text @search-text
                             :tab-group   tab-group
                             :story       @story})]
    (fn briefing-column-view-render [tab-group]
      [:div.briefing
       [:div.tile-tabs
        [:div.journal
         [:div.journal-entries
          [briefing-view @local-cfg]]]]])))
