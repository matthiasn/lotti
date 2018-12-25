(ns meo.electron.renderer.ui.entry.entry
  (:require [meo.electron.renderer.ui.leaflet :as l]
            [meo.electron.renderer.ui.mapbox :as mb]
            [meo.electron.renderer.ui.media :as m]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.common.utils.parse :as up]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [meo.electron.renderer.ui.entry.datetime :as dt]
            [meo.electron.renderer.ui.entry.actions :as a]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.electron.renderer.ui.entry.capture :as c]
            [meo.electron.renderer.ui.entry.task :as task]
            [meo.electron.renderer.ui.entry.cfg.habit :as habit]
            [meo.electron.renderer.ui.entry.cfg.dashboard :as db]
            [meo.electron.renderer.ui.entry.cfg.custom-field :as cfc]
            [meo.electron.renderer.ui.entry.reward :as reward]
            [meo.electron.renderer.ui.entry.story :as es]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.electron.renderer.ui.entry.carousel :as cl]
            [meo.electron.renderer.ui.entry.img.carousel :as icl]
            [meo.electron.renderer.ui.entry.wavesurfer :as ws]
            [meo.common.utils.misc :as u]
            [meo.electron.renderer.ui.entry.conflict :as ec]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.draft :as d]
            [clojure.set :as set]
            [clojure.data :as cd]
            [moment]
            [meo.electron.renderer.ui.entry.pomodoro :as pomo]
            [clojure.pprint :as pp]
            [reagent.core :as r]
            [matthiasn.systems-toolbox.component :as st]))

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
  (let [
        ts (:timestamp entry)
        cfg (subscribe [:cfg])
        {:keys [edit-mode new-entry]} (eu/entry-reaction ts)
        show-map? (reaction (contains? (:show-maps-for @cfg) ts))
        active (reaction (:active @cfg))
        backend-cfg (subscribe [:backend-cfg])
        tab-group (:tab-group local-cfg)
        drop-fn (a/drop-linked-fn entry cfg emit)
        local (r/atom {:scroll-disabled true
                       :show-adjust-ts  false})]
    (fn journal-entry-render [entry emit local-cfg]
      (let [merged (merge entry @new-entry)
            {:keys [latitude longitude]} merged
            edit-mode? @edit-mode
            toggle-edit #(if @edit-mode (emit [:entry/remove-local entry])
                                        (emit [:entry/update-local entry]))
            mapbox-token (:mapbox-token @backend-cfg)
            qid (:query-id local-cfg)
            map-id (str ts (when qid (name qid)))
            errors (cfc/validate-cfg @new-entry backend-cfg)
            on-drag-start (a/drag-start-fn entry emit)]
        [:div.entry {:on-drop       drop-fn
                     :on-drag-over  h/prevent-default
                     :on-drag-enter h/prevent-default
                     :draggable     true
                     :on-drag-start on-drag-start}
         [:div.header-1
          [:div [es/story-select merged tab-group]]
          [linked-btn merged local-cfg active]]
         [:div.header
          (when (:show-adjust-ts @local)
            [dt/datetime-edit merged local])
          [:div.action-row
           [dt/datetime-header merged local]
           [a/entry-actions merged local emit edit-mode? toggle-edit local-cfg]]]
         (when (= :custom-field-cfg (:entry_type merged))
           [cfc/custom-field-config merged])
         (when-not (:spotify entry)
           [d/entry-editor entry errors emit])
         [es/story-form merged]
         [es/saga-name-field merged edit-mode?]
         (when (or (contains? (set (:perm_tags entry)) "#task")
                   (contains? (set (:tags entry)) "#task"))
           [task/task-details merged local-cfg edit-mode?])
         (when (or (= :habit (:entry-type merged))
                   (= :habit (:entry_type merged)))
           [habit/habit-details merged emit])
         (when (= :dashboard-cfg (:entry_type merged))
           [db/dashboard-config merged emit])
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
             [l/leaflet-map merged @show-map? local-cfg emit]))
         [m/imdb-view merged]
         [m/spotify-view merged]
         [c/questionnaire-div merged edit-mode?]
         (when (:debug @local)
           [:div.debug
            [:h3 "from backend"]
            [:pre [:code (with-out-str (pp/pprint entry))]]
            [:h3 "@new-entry"]
            [:pre [:code (with-out-str (pp/pprint @new-entry))]]
            [:h3 "diff"]
            [:pre [:code (with-out-str (pp/pprint (cd/diff entry @new-entry)))]]])]))))

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
            thumbnails? (and (not (contains? (:tags entry) "#briefing"))
                             (:thumbnails @cfg))]
        [:div.entry-with-comments
         [journal-entry entry emit local-cfg]
         (when thumbnails?
           [icl/gallery (icl/gallery-entries entry) local-cfg emit])
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
                [journal-entry comment emit local-cfg])]
             [:div.show-comments
              (let [n (count comments)]
                [:span {:on-click toggle-comments}
                 (str "show " n " comment" (when (> n 1) "s"))])]))]))))
