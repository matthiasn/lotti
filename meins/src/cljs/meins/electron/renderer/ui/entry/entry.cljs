(ns meins.electron.renderer.ui.entry.entry
  (:require [clojure.set :as set]
            [meins.common.utils.misc :as u]
            [meins.common.utils.parse :as up]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.draft :as d]
            [meins.electron.renderer.ui.entry.actions :as a]
            [meins.electron.renderer.ui.entry.capture :as c]
            [meins.electron.renderer.ui.entry.cfg.album :as ca]
            [meins.electron.renderer.ui.entry.cfg.custom-field :as cfc]
            [meins.electron.renderer.ui.entry.cfg.dashboard :as db]
            [meins.electron.renderer.ui.entry.cfg.habit :as habit]
            [meins.electron.renderer.ui.entry.conflict :as ec]
            [meins.electron.renderer.ui.entry.datetime :as dt]
            [meins.electron.renderer.ui.entry.debug :as dbg]
            [meins.electron.renderer.ui.entry.img.carousel :as icl]
            [meins.electron.renderer.ui.entry.pomodoro :as pomo]
            [meins.electron.renderer.ui.entry.post-mortem :as pm]
            [meins.electron.renderer.ui.entry.problem :as prb]
            [meins.electron.renderer.ui.entry.reward :as reward]
            [meins.electron.renderer.ui.entry.story :as es]
            [meins.electron.renderer.ui.entry.task :as task]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [meins.electron.renderer.ui.entry.wavesurfer :as ws]
            [meins.electron.renderer.ui.leaflet :as l]
            [meins.electron.renderer.ui.mapbox :as mb]
            [meins.electron.renderer.ui.media :as m]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug error info]]))

(defn hashtags-mentions [entry tab-group]
  (let [clear-import #(emit [:entry/update (update entry :tags disj "#import")])
        tags (set/union (:tags entry) (:perm_tags entry))]
    [:div.hashtags
     (when (contains? tags "#import")
       [:span.hashtag {:on-click clear-import} "#import"])
     (for [mention (:mentions entry)]
       ^{:key (str "mention-" mention)}
       [:span.mention {:on-click (up/add-search {:tab-group    tab-group
                                                 :story-name   mention
                                                 :first-line   mention
                                                 :query-string mention} emit)} mention])
     (for [tag (disj tags "#import")]
       ^{:key (str "tag-" tag)}
       [:span.hashtag {:on-click (up/add-search {:tab-group    tab-group
                                                 :story-name   tag
                                                 :first-line   tag
                                                 :query-string tag} emit)} tag])]))

(defn linked-btn [entry local-cfg active]
  (when (pos? (:linked_cnt entry))
    (let [ts (:timestamp entry)
          text (eu/first-line entry)
          story-name (get-in entry [:story :story_name])
          tab-group (:tab-group local-cfg)
          open-linked (up/add-search {:tab-group    tab-group
                                      :story-name   story-name
                                      :first-line   (str "linked for: " text)
                                      :query-string (str "l:" ts)}
                                     emit)
          entry-active? (when-let [query-id (:query-id local-cfg)]
                          (= (query-id @active) ts))]
      [:div
       [:span.link-btn {:on-click open-linked
                        :class    (when entry-active? "active")}
        (str "linked: " (:linked_cnt entry))]])))

(defn linked-btn2 [entry local-cfg]
  (let [ts (:timestamp entry)
        tab-group (:tab-group local-cfg)
        open-linked (up/add-search {:tab-group    tab-group
                                    :query-string (str ts)}
                                   emit)]
    [:div
     [:span.link-btn {:on-click open-linked}
      (str "open linked")]]))

(defn git-commit [_entry]
  (let [repos (subscribe [:repos])]
    (fn [entry]
      (when-let [gc (:git_commit entry)]
        (let [{:keys [repo_name refs commit subject abbreviated_commit]} gc
              cfg (get-in @repos [repo_name])
              url (str (:repo-url cfg) "/commit/" commit)]
          [:div.git-commit
           [:span.repo-name (str repo_name ":")]
           "[" [:a {:href url :target "_blank"} abbreviated_commit] "] "
           (when (seq refs) (str "(" refs ") "))
           subject])))))

(defn journal-entry
  "Renders individual journal entry. Interaction with application state happens
   via messages that are sent to the store component, for example for toggling
   the display of the edit mode or showing the map for an entry. The editable
   content component used in edit mode also sends a modified entry to the store
   component, which is useful for displaying updated hashtags, or also for
   showing the warning that the entry is not saved yet."
  [entry local-cfg]
  (let [ts (:timestamp entry)
        cfg (subscribe [:cfg])
        {:keys [edit-mode new-entry]} (eu/entry-reaction ts)
        show-map? (reaction (and (not (:hide-map local-cfg))
                                 (contains? (:show-maps-for @cfg) ts)))
        active (reaction (:active @cfg))
        backend-cfg (subscribe [:backend-cfg])
        tab-group (:tab-group local-cfg)
        local (r/atom {:scroll-disabled true
                       :show-adjust-ts  false})]
    (fn journal-entry-render [entry local-cfg]
      (let [is-linked (:linked-inline (meta entry))
            merged (merge entry @new-entry)
            {:keys [latitude longitude]} merged
            edit-mode? @edit-mode
            toggle-edit #(if @edit-mode (emit [:entry/remove-local entry])
                                        (emit [:entry/update-local entry]))
            mapbox-token (:mapbox-token @backend-cfg)
            qid (:query-id local-cfg)
            drop-fn (a/drop-linked-fn entry cfg)
            map-id (str ts (when qid (name qid)))
            errors (cfc/validate-cfg @new-entry backend-cfg)
            on-drag-start (a/drag-start-fn entry)]
        [:div.entry {:id            (str tab-group ts)
                     :on-drop       drop-fn
                     :on-drag-over  h/prevent-default
                     :on-drag-enter h/prevent-default
                     :draggable     true
                     :on-drag-start on-drag-start
                     :class         (when is-linked "linked-inline")}
         [:div.drag
          [:div.header-1
           [:div (when-not is-linked [es/story-select merged tab-group])]
           [linked-btn merged local-cfg active]
           (when is-linked [linked-btn2 merged local-cfg])]
          [:div.header
           [:div.action-row
            (if (:show-adjust-ts @local)
              [dt/datetime-edit merged]
              [dt/datetime-header merged local])
            [a/entry-actions merged local edit-mode? toggle-edit local-cfg]]]]
         [prb/problem-form merged local-cfg]
         [prb/problem-review-form merged]
         (when (= :custom-field-cfg (:entry_type merged))
           [cfc/custom-field-config merged])
         (when-not (:spotify entry)
           [d/entry-editor entry errors])
         [es/story-form merged]
         [es/saga-name-field merged]
         (when (or (contains? (set (:perm_tags entry)) "#task")
                   (contains? (set (:tags entry)) "#task"))
           [task/task-details merged])
         #_(when (or (contains? (set (:perm_tags entry)) "#album")
                     (contains? (set (:tags entry)) "#album"))
             [ca/album-config merged])
         (when (or (contains? (set (:perm_tags entry)) "#post-mortem")
                   (contains? (set (:tags entry)) "#post-mortem"))
           [pm/post-mortem merged])
         (when (or (= :habit (:entry-type merged))
                   (= :habit (:entry_type merged)))
           [habit/habit-details merged emit])
         (when (= :dashboard-cfg (:entry_type merged))
           [db/dashboard-config merged])
         (when (contains? (set (:tags entry)) "#reward")
           [reward/reward-details merged emit])
         (let [pomodoro (= :pomodoro (:entry_type entry))]
           [:div.entry-footer
            (when pomodoro
              [pomo/pomodoro-btn merged edit-mode?])
            (when pomodoro
              [pomo/pomodoro-time merged edit-mode?])
            (when-not pomodoro
              [pomo/pomodoro-footer entry])
            [hashtags-mentions entry tab-group]
            [:div.word-count (u/count-words-formatted merged)]])
         [ec/conflict-view merged]
         [c/custom-fields-div merged emit edit-mode?]
         (when (:git_commit entry)
           [git-commit merged])
         [ws/wavesurfer merged local-cfg]
         (when (and @show-map?
                    latitude
                    longitude
                    (not (and (zero? latitude)
                              (zero? longitude))))
           (if mapbox-token
             [:div.entry-mapbox
              {:on-click #(swap! local update-in [:scroll-disabled] not)}
              [mb/mapbox-cls {:local           local
                              :id              map-id
                              :selected        merged
                              :scroll-disabled (:scroll-disabled @local)
                              :local-cfg       local-cfg
                              :mapbox-token    mapbox-token}]]
             [l/leaflet-map merged @show-map? local-cfg]))
         [m/imdb-view merged]
         [m/spotify-view merged]
         [c/questionnaire-div merged edit-mode?]
         (when is-linked
           [icl/gallery entry [entry] local-cfg emit])
         (dbg/debug-view entry new-entry local)]))))

(defn entry-with-comments
  "Renders individual journal entry. Interaction with application state happens
   via messages that are sent to the store component, for example for toggling
   the display of the edit mode or showing the map for an entry. The editable
   content component used in edit mode also sends a modified entry to the store
   component, which is useful for displaying updated hashtags, or also for
   showing that the entry is not saved yet."
  [entry local-cfg]
  (let [ts (:timestamp entry)
        cfg (subscribe [:cfg])
        show-comments-for? (reaction (get-in @cfg [:show-comments-for ts]))
        query-id (:query-id local-cfg)
        toggle-comments #(emit [:cmd/assoc-in
                                {:path  [:cfg :show-comments-for ts]
                                 :value (when-not (= @show-comments-for? query-id)
                                          query-id)}])]
    (fn entry-with-comments-render [entry local-cfg]
      (let [comments (:comments entry)
            linked (map #(with-meta % {:linked-inline true}) (:linked entry))
            comments-linked (filter
                              (fn [entry] (not (:briefing entry)))
                              (sort-by :timestamp (concat comments linked)))
            thumbnails? (and (not (contains? (:tags entry) "#briefing"))
                             (:thumbnails @cfg)
                             (not (:gallery-view local-cfg))
                             (:img_file entry))]
        [:div.entry-with-comments
         [journal-entry entry local-cfg]
         (when thumbnails?
           [icl/gallery entry (icl/gallery-entries entry) local-cfg emit])
         (when (seq comments-linked)
           (if (= query-id @show-comments-for?)
             [:div.comments
              (let [n (count comments-linked)]
                [:div.show-comments
                 (when (pos? n)
                   [:span {:on-click toggle-comments}
                    (str "hide " n " comment" (when (> n 1) "s"))])])
              (for [comment comments-linked]
                ^{:key (str "c" comment)}
                [journal-entry comment local-cfg])]
             [:div.show-comments
              (let [n (count comments-linked)]
                [:span {:on-click toggle-comments}
                 (str "show " n " comment" (when (> n 1) "s"))])]))]))))
