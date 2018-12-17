(ns meo.electron.renderer.ui.entry.entry
  (:require [meo.electron.renderer.ui.leaflet :as l]
            [meo.electron.renderer.ui.mapbox :as mb]
            [meo.electron.renderer.ui.media :as m]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.common.utils.parse :as up]
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

(defn hashtags-mentions [entry tab-group put-fn]
  (let [clear-import #(put-fn [:entry/update (update entry :tags disj "#import")])
        tags (set/union (:tags entry) (:perm_tags entry))]
    [:div.hashtags
     (when (contains? tags "#import")
       [:span.hashtag {:on-click clear-import} "#import"])
     (for [mention (:mentions entry)]
       ^{:key (str "mention-" mention)}
       [:span.mention {:on-click (up/add-search mention tab-group put-fn)} mention])
     (for [tag (disj tags "#import")]
       ^{:key (str "tag-" tag)}
       [:span.hashtag {:on-click (up/add-search tag tab-group put-fn)} tag])]))

(defn linked-btn [entry local-cfg active put-fn]
  (when (pos? (:linked_cnt entry))
    (let [ts (:timestamp entry)
          tab-group (:tab-group local-cfg)
          open-linked (up/add-search (str "l:" ts) tab-group put-fn)
          entry-active? (when-let [query-id (:query-id local-cfg)]
                          (= (query-id @active) ts))]
      [:div
       [:span.link-btn {:on-click open-linked
                        :class    (when entry-active? "active")}
        (str "linked: " (:linked_cnt entry))]])))

(defn git-commit [_entry _put-fn]
  (let [repos (subscribe [:repos])]
    (fn [entry put-fn]
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
  [entry put-fn local-cfg]
  (let [ts (:timestamp entry)
        cfg (subscribe [:cfg])
        {:keys [edit-mode new-entry]} (eu/entry-reaction ts)
        show-map? (reaction (contains? (:show-maps-for @cfg) ts))
        active (reaction (:active @cfg))
        backend-cfg (subscribe [:backend-cfg])
        tab-group (:tab-group local-cfg)
        drop-fn (a/drop-linked-fn entry cfg put-fn)
        local (r/atom {:scroll-disabled true
                       :show-adjust-ts  false})]
    (fn journal-entry-render [entry put-fn local-cfg]
      (let [merged (merge entry @new-entry)
            {:keys [latitude longitude]} merged
            edit-mode? @edit-mode
            toggle-edit #(if @edit-mode (put-fn [:entry/remove-local entry])
                                        (put-fn [:entry/update-local entry]))
            mapbox-token (:mapbox-token @backend-cfg)
            qid (:query-id local-cfg)
            map-id (str ts (when qid (name qid)))
            errors (cfc/validate-cfg @new-entry backend-cfg)]
        [:div.entry {:on-drop       drop-fn
                     :on-drag-over  h/prevent-default
                     :on-drag-enter h/prevent-default}
         [:div.header-1
          [:div [es/story-select merged tab-group put-fn]]
          [linked-btn merged local-cfg active put-fn]]
         [:div.header
          (when (:show-adjust-ts @local)
            [dt/datetime-edit merged local put-fn])
          [:div.action-row
           [dt/datetime-header merged local put-fn]
           [a/entry-actions merged local put-fn edit-mode? toggle-edit local-cfg]]]
         [es/story-form merged put-fn]
         [es/saga-name-field merged edit-mode? put-fn]
         (when (= :custom-field-cfg (:entry_type merged))
           [cfc/custom-field-config merged put-fn])
         (when-not (:spotify entry)
           [d/entry-editor entry errors put-fn])
         (when (or (contains? (set (:perm_tags entry)) "#task")
                   (contains? (set (:tags entry)) "#task"))
           [task/task-details merged local-cfg put-fn edit-mode?])
         (when (or (= :habit (:entry-type merged))
                   (= :habit (:entry_type merged)))
           [habit/habit-details merged put-fn])
         (when (= :dashboard-cfg (:entry_type merged))
           [db/dashboard-config merged put-fn])
         (when (contains? (set (:tags entry)) "#reward")
           [reward/reward-details merged put-fn])
         (let [pomodoro (= :pomodoro (:entry_type entry))]
           [:div.entry-footer
            (when pomodoro
              [pomo/pomodoro-btn merged edit-mode? put-fn])
            (when pomodoro
              [pomo/pomodoro-time merged edit-mode? put-fn])
            (when-not pomodoro
              [pomo/pomodoro-footer entry put-fn])
            [hashtags-mentions entry tab-group put-fn]
            [:div.word-count (u/count-words-formatted merged)]])
         [ec/conflict-view merged put-fn]
         [c/custom-fields-div merged put-fn edit-mode?]
         (when (:git_commit entry)
           [git-commit merged put-fn])
         [ws/wavesurfer merged local-cfg put-fn]
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
                              :mapbox-token    mapbox-token
                              :put-fn          put-fn}]]
             [l/leaflet-map merged @show-map? local-cfg put-fn]))
         [m/imdb-view merged put-fn]
         [m/spotify-view merged put-fn]
         [c/questionnaire-div merged put-fn edit-mode?]
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
  [entry put-fn local-cfg]
  (let [ts (:timestamp entry)
        cfg (subscribe [:cfg])
        show-comments-for? (reaction (get-in @cfg [:show-comments-for ts]))
        query-id (:query-id local-cfg)
        toggle-comments #(put-fn [:cmd/assoc-in
                                  {:path  [:cfg :show-comments-for ts]
                                   :value (when-not (= @show-comments-for? query-id)
                                            query-id)}])]
    (fn entry-with-comments-render [entry put-fn local-cfg]
      (let [comments (:comments entry)
            thumbnails? (and (not (contains? (:tags entry) "#briefing"))
                             (:thumbnails @cfg))]
        [:div.entry-with-comments
         [journal-entry entry put-fn local-cfg]
         (when thumbnails?
           [cl/gallery (cl/gallery-entries entry) local-cfg put-fn])
         (when (seq comments)
           (if (not (= query-id @show-comments-for?))
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
