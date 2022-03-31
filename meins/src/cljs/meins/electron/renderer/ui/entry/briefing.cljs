(ns meins.electron.renderer.ui.entry.briefing
  (:require [clojure.string :as s]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.common.utils.misc :as u]
            [meins.common.utils.parse :as up]
            [meins.electron.renderer.charts.data :as cd]
            [meins.electron.renderer.graphql :as gql]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.charts.common :as cc]
            [meins.electron.renderer.ui.entry.actions :as a]
            [meins.electron.renderer.ui.entry.briefing.habits :as habits]
            [meins.electron.renderer.ui.entry.briefing.tasks :as tasks]
            [meins.electron.renderer.ui.entry.entry :as e]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug info]]))

(defn planned-actual [_entry]
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
            sorted (sort-by #(u/lower-case (or (:saga_name (second %)) "")) @sagas)]
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

(defn add-task [_ts]
  (let [open-new (fn [x]
                   (emit
                     [:schedule/new
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
      [:div.add-task
       [:div.toggle-visible
        {:on-click click}
        "show all"
        [:i.fas.fa-chevron-square-right]]])))

(defn problems-gql-query [n]
  (let [queries [[:problems
                  {:search-text "#problem"
                   :n           n}]]
        query (gql/tabs-query queries false true)]
    (emit [:gql/query {:q        query
                       :id       :problems
                       :res-hash nil
                       :prio     11}])))

(defn problems-view []
  (let [gql-res (subscribe [:gql-res2])
        pvt (subscribe [:show-pvt])
        problems (reaction (let [res (-> @gql-res :problems :res vals)
                                 pvt @pvt]
                             (->> res
                                  (filter :problem_cfg)
                                  (filter #(if pvt true (not (-> % :problem_cfg :pvt))))
                                  (filter #(-> % :problem_cfg :active)))))]
    (problems-gql-query 1000)
    (fn []
      [:div.problems
       [:table
        [:tbody
         [:tr
          [:th "Problem"]
          [:th "Last Review"]
          [:th "Reviews"]]
         (for [p @problems]
           (let [reviews (->> p
                              :comments
                              (filter #(= :problem-review (:entry_type %)))
                              (sort-by :timestamp))
                 last-ts (:timestamp (or (last reviews) p))
                 since-last-review (- (stc/now) last-ts)
                 last-review (str (h/time-ago since-last-review) " ago")
                 last-review (s/replace last-review "minutes" "min")
                 last-review (s/replace last-review "a few seconds ago" "just now")
                 cls (when (> since-last-review (* 7 24 60 60 1000)) "due")]
             ^{:key (:timestamp p)}
             [:tr {:class    cls
                   :on-click (up/add-search {:tab-group    :right
                                             :query-string (:timestamp p)} emit)}
              [:td (-> p :problem_cfg :name)]
              [:td last-review]
              [:td
               (for [r (take-last 12 reviews)]
                 (let [cls (some-> r :problem_review :conclusion name)]
                   ^{:key (:timestamp r)}
                   [:span.conclusion {:class cls}]))]]))]]])))

(defn briefing-view [_local-cfg]
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
    (h/to-day (h/ymd (stc/now)) pvt)
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
            drop-fn (a/drop-on-briefing @briefing cfg)]
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
           [tasks/started-tasks local {:on-hold false}]]
          [h/error-boundary
           [tasks/open-linked-tasks local local-cfg]]
          [problems-view]
          [:div.habit-details
           [habits/waiting-habits local]]
          [h/error-boundary
           [tasks/started-tasks local {:on-hold true}]]
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
              [e/journal-entry comment local-cfg])]]
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
    (fn briefing-column-view-render [_tab-group]
      [:div.briefing-container
       [:div.tile-tabs
        [:div.journal
         [:div.journal-entries
          [briefing-view @local-cfg]]]]])))
