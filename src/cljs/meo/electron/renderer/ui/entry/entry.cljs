(ns meo.electron.renderer.ui.entry.entry
  (:require [meo.electron.renderer.ui.leaflet :as l]
            [meo.electron.renderer.ui.media :as m]
            [meo.electron.renderer.ui.entry.pomodoro :as pomo]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.common.utils.parse :as up]
            [meo.electron.renderer.ui.entry.actions :as a]
            [meo.electron.renderer.ui.entry.location :as loc]
            [meo.electron.renderer.ui.entry.capture :as c]
            [meo.electron.renderer.ui.entry.task :as task]
            [meo.electron.renderer.ui.entry.habit :as habit]
            [meo.electron.renderer.ui.entry.reward :as reward]
            [meo.electron.renderer.ui.entry.briefing :as b]
            [meo.electron.renderer.ui.entry.flight :as f]
            [meo.electron.renderer.ui.entry.story :as es]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.electron.renderer.ui.entry.thumbnails :as t]
            [moment]
            [meo.common.utils.misc :as u]
            [meo.electron.renderer.helpers :as h]
            [clojure.set :as set]
            [meo.electron.renderer.ui.draft :as d]
            [meo.common.utils.parse :as p]))

(defn all-comments-set [ts]
  (let [{:keys [entry combined-entries new-entries]} (eu/entry-reaction ts)
        comments-set (reaction (set (:comments @entry)))
        comments-filter (fn [[_ts c]] (= (:comment-for c) ts))
        local-comments (reaction (into {} (filter comments-filter @new-entries)))]
    (reaction (sort (set/union (set (:comments @entry))
                               (set (keys @local-comments)))))))

(defn total-time-logged [ts]
  (let [{:keys [entry combined-entries]} (eu/entry-reaction ts)
        planning-mode (subscribe [:planning-mode])
        all-comments-set (all-comments-set ts)
        total-dur (reaction
                    (apply + (map #(:completed-time (get @combined-entries %))
                                  @all-comments-set)))]
    (fn [ts]
      (when (and (pos? @total-dur) @planning-mode)
        [:span [:span.fa.fa-clock-o.completed]
         [:span.dur (u/duration-string @total-dur)]]))))

(defn hashtags-mentions-list [ts tab-group put-fn]
  (let [cfg (subscribe [:cfg])
        entry (:entry (eu/entry-reaction ts))]
    (fn hashtags-mentions-render [ts tab-group put-fn]
      [:div.hashtags
       (for [mention (:mentions @entry)]
         ^{:key (str "tag-" mention)}
         [:span.mention {:on-click (up/add-search mention tab-group put-fn)}
          mention])
       (for [hashtag (:tags @entry)]
         ^{:key (str "tag-" hashtag)}
         [:span.hashtag {:on-click (up/add-search hashtag tab-group put-fn)}
          hashtag])])))

(defn journal-entry
  "Renders individual journal entry. Interaction with application state happens
   via messages that are sent to the store component, for example for toggling
   the display of the edit mode or showing the map for an entry. The editable
   content component used in edit mode also sends a modified entry to the store
   component, which is useful for displaying updated hashtags, or also for
   showing the warning that the entry is not saved yet."
  [ts put-fn local-cfg]
  (let [cfg (subscribe [:cfg])
        {:keys [entry edit-mode entries-map new-entries]} (eu/entry-reaction ts)
        linked-desc (reaction (get @entries-map (:linked-timestamp @entry)))
        show-map? (reaction (contains? (:show-maps-for @cfg) ts))
        active (reaction (:active @cfg))
        q-date-string (.format (moment ts) "YYYY-MM-DD")
        formatted-time (.format (moment ts) "ddd YY-MM-DD HH:mm")
        tab-group (:tab-group local-cfg)
        add-search (up/add-search q-date-string tab-group put-fn)
        open-linked (up/add-search (str "l:" ts) tab-group put-fn)
        drop-fn (a/drop-linked-fn entry entries-map cfg put-fn)
        toggle-edit #(if @edit-mode (put-fn [:entry/remove-local @entry])
                                    (put-fn [:entry/update-local @entry]))]
    (fn journal-entry-render [ts put-fn local-cfg]
      (let [edit-mode? @edit-mode
            linked-desc @linked-desc]
        [:div.entry {:on-drop       drop-fn
                     :on-drag-over  h/prevent-default
                     :on-drag-enter h/prevent-default}
         [:div.header-1
          [:div
           [es/story-div entry tab-group put-fn]
           [es/saga-select @entry put-fn edit-mode?]]
          [loc/geonames entry put-fn edit-mode?]]
         [:div.header
          [:div
           [:a [:time {:on-click add-search} formatted-time]]
           [:time (u/visit-duration @entry)]]
          (if (= :pomodoro (:entry-type @entry))
            [pomo/pomodoro-header entry edit-mode? put-fn]
            [:div (when-not (:comment-for @entry) [total-time-logged ts])])
          [:div
           (when (seq (:linked-entries-list @entry))
             (let [ts (:timestamp @entry)
                   entry-active? (when-let [query-id (:query-id local-cfg)]
                                   (= (query-id @active) ts))]
               [:span.link-btn {:on-click open-linked
                                :class    (when entry-active? "active")}
                (str " linked: " (count (:linked-entries-list @entry)))]))]
          [a/entry-actions ts put-fn edit-mode? toggle-edit local-cfg]]
         [es/story-name-field @entry edit-mode? put-fn]
         [es/saga-name-field @entry edit-mode? put-fn]
         [d/entry-editor entry put-fn]
         [c/custom-fields-div @entry put-fn edit-mode?]
         [c/questionnaire-div @entry put-fn edit-mode?]
         [m/audioplayer-view @entry put-fn]
         [l/leaflet-map @entry @show-map? local-cfg put-fn]
         [loc/location-details @entry put-fn edit-mode?]
         [m/image-view entry]
         [m/videoplayer-view @entry]
         [m/imdb-view @entry put-fn]
         [m/spotify-view @entry put-fn]
         [task/task-details @entry local-cfg put-fn edit-mode?]
         [habit/habit-details @entry local-cfg put-fn edit-mode?]
         [reward/reward-details @entry put-fn edit-mode?]
         (when (contains? (:tags @entry) "#briefing")
           [b/briefing-view @entry put-fn edit-mode? local-cfg])
         [f/flight-view @entry put-fn edit-mode? local-cfg]
         [:div.footer
          [hashtags-mentions-list ts tab-group put-fn]
          [:div.word-count (u/count-words-formatted @entry)]]]))))

(defn entry-with-comments
  "Renders individual journal entry. Interaction with application state happens
   via messages that are sent to the store component, for example for toggling
   the display of the edit mode or showing the map for an entry. The editable
   content component used in edit mode also sends a modified entry to the store
   component, which is useful for displaying updated hashtags, or also for
   showing the warning that the entry is not saved yet."
  [ts put-fn local-cfg]
  (let [{:keys [entry new-entries]} (eu/entry-reaction ts)
        all-comments-set (all-comments-set ts)
        new-entry (reaction (get @new-entries ts))
        cfg (subscribe [:cfg])
        options (subscribe [:options])
        show-pvt? (reaction (:show-pvt @cfg))
        entries-map (subscribe [:entries-map])
        comments (reaction
                   (let [comments (map (fn [ts]
                                         (or (get @new-entries ts)
                                             (get @entries-map ts)))
                                       @all-comments-set)
                         pvt-filter (u/pvt-filter @options @entries-map)
                         comments (if @show-pvt?
                                    comments
                                    (filter pvt-filter comments))]
                     (map :timestamp comments)))
        thumbnails? (reaction (and (not (contains? (:tags @entry) "#briefing"))
                                   (:thumbnails @cfg)))
        show-comments-for? (reaction (get-in @cfg [:show-comments-for ts]))
        query-id (:query-id local-cfg)
        toggle-comments #(put-fn [:cmd/assoc-in
                                  {:path  [:cfg :show-comments-for ts]
                                   :value (when-not (= @show-comments-for? query-id)
                                            query-id)}])]
    (fn entry-with-comments-render [ts put-fn local-cfg]
      (let [entry @entry
            comments @comments]
        [:div.entry-with-comments
         [journal-entry ts put-fn local-cfg]
         (when @thumbnails? [t/thumbnails entry local-cfg put-fn])
         (when (seq comments)
           (if (= query-id @show-comments-for?)
             [:div.comments
              (let [n (count comments)]
                [:div.show-comments
                 (when (pos? n)
                   [:span {:on-click toggle-comments}
                    (str "hide " n " comment" (when (> n 1) "s"))])])
              (for [comment comments]
                ^{:key (str "c" comment)}
                [journal-entry comment put-fn local-cfg])]
             [:div.show-comments
              (let [n (count comments)]
                [:span {:on-click toggle-comments}
                 (str "show " n " comment" (when (> n 1) "s"))])]))]))))
