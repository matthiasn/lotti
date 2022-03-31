(ns meins.electron.renderer.ui.focus
  (:require ["react-event-timeline" :refer [Timeline TimelineEvent]]
            ["react-horizontal-timeline" :default rht]
            [meins.common.utils.parse :as up]
            [meins.electron.renderer.graphql :as gql]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.entry :as e]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [meins.electron.renderer.ui.grid :as g]
            [meins.electron.renderer.ui.journal :as j]
            [meins.electron.renderer.ui.menu :as menu]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.stats :as stats]
            [meins.electron.renderer.ui.updater :as upd]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug info]]))

(def timeline (r/adapt-react-class Timeline))
(def timeline-event (r/adapt-react-class TimelineEvent))

(def horizontal-timeline (r/adapt-react-class rht))

(defn entry-card [_entry _local]
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
                     :else nil)
            status-cls (case status
                         "rejected" "fa-times red"
                         "comment" "fa-comment"
                         "completed" "fa-check green"
                         "open" "fa-check"
                         "commit" "fa-code-commit"
                         "img" "fa-image"
                         "fa-sticky-note")
            on-click (fn [_ev]
                       (let [el (.getElementById js/document (str ":left" ts))]
                         (if el
                           (do
                             (.scrollIntoViewIfNeeded el (clj->js {:behavior "smooth"}))
                             (.scroll js/window 0 0))
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
    (fn tabs-render [_tab-group]
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
                           (.scrollIntoViewIfNeeded el (clj->js {:behavior "smooth"}))
                           ;(.scroll js/window 0 0)
                           ) ))]
    (fn [_local]
      [:div.post-mortem-timeline
       [horizontal-timeline
        {:values      @combined
         :index       (:tl-idx @local)
         :indexClick  click
         :linePadding 60}]])))

(defn focus-page []
  (let [local (r/atom {:tl-idx 0})]
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
