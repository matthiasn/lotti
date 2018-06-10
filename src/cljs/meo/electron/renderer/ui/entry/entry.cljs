(ns meo.electron.renderer.ui.entry.entry
  (:require [meo.electron.renderer.ui.leaflet :as l]
            [meo.electron.renderer.ui.mapbox :as mb]
            [meo.electron.renderer.ui.media :as m]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.common.utils.parse :as up]
            [meo.electron.renderer.ui.entry.actions :as a]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.electron.renderer.ui.entry.location :as loc]
            [meo.electron.renderer.ui.entry.capture :as c]
            [meo.electron.renderer.ui.entry.task :as task]
            [meo.electron.renderer.ui.entry.habit :as habit]
            [meo.electron.renderer.ui.entry.reward :as reward]
            [meo.electron.renderer.ui.entry.story :as es]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.electron.renderer.ui.entry.carousel :as cl]
            [meo.electron.renderer.ui.entry.wavesurfer :as ws]
            [meo.common.utils.misc :as u]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.draft :as d]
            [clojure.set :as set]
            [clojure.data :as cd]
            [moment]
            [meo.electron.renderer.ui.entry.pomodoro :as pomo]
            [clojure.pprint :as pp]
            [reagent.core :as r]))

(defn hashtags-mentions-list [entry tab-group put-fn]
  [:div.hashtags
   (for [mention (:mentions entry)]
     ^{:key (str "tag-" mention)}
     [:span.mention {:on-click (up/add-search mention tab-group put-fn)}
      mention])
   (for [hashtag (set/union (:tags entry) (:perm_tags entry))]
     ^{:key (str "tag-" hashtag)}
     [:span.hashtag {:on-click (up/add-search hashtag tab-group put-fn)}
      hashtag])])

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
        (str " linked: " (:linked_cnt entry))]])))

(defn conflict-view [entry put-fn]
  (let []
    (fn [entry put-fn]
      (when-let [conflict (:conflict entry)]
        [:div.conflict
         [:div.warn [:span.fa.fa-exclamation] "Conflict"]
         [:pre [:code (with-out-str (pp/pprint conflict))]]]))))

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
        q-date-string (.format (moment ts) "YYYY-MM-DD")
        tab-group (:tab-group local-cfg)
        add-search (up/add-search q-date-string tab-group put-fn)
        drop-fn (a/drop-linked-fn entry cfg put-fn)
        local (r/atom {:scroll-disabled true})]
    (fn journal-entry-render [entry put-fn local-cfg]
      (let [merged (merge entry @new-entry)
            edit-mode? @edit-mode
            locale (:locale @cfg :en)
            toggle-edit #(if @edit-mode (put-fn [:entry/remove-local entry])
                                        (put-fn [:entry/update-local entry]))
            formatted-time (h/localize-datetime (moment ts) locale)
            mapbox-token (:mapbox-token @backend-cfg)
            qid (:query-id local-cfg)
            map-id (str ts (when qid (name qid)))]
        [:div.entry {:on-drop       drop-fn
                     :on-drag-over  h/prevent-default
                     :on-drag-enter h/prevent-default}
         [:div.header-1
          [:div
           [es/story-select entry put-fn]
           [es/saga-select merged put-fn edit-mode?]]
          [loc/geonames entry put-fn]]
         [:div.header
          [:div
           [:a [:time {:on-click add-search} formatted-time]]
           [:time (u/visit-duration merged)]]
          [linked-btn merged local-cfg active put-fn]
          [a/entry-actions merged local put-fn edit-mode? toggle-edit local-cfg]]
         [es/story-name-field merged edit-mode? put-fn]
         [es/saga-name-field merged edit-mode? put-fn]
         [d/entry-editor entry put-fn]
         [task/task-details merged local-cfg put-fn edit-mode?]
         [habit/habit-details merged local-cfg put-fn edit-mode?]
         [reward/reward-details merged put-fn]
         [:div.footer
          [pomo/pomodoro-header merged edit-mode? put-fn]
          [hashtags-mentions-list entry tab-group put-fn]
          [:div.word-count (u/count-words-formatted merged)]]
         [conflict-view merged put-fn]
         [c/custom-fields-div merged put-fn edit-mode?]
         [git-commit merged put-fn]
         [ws/wavesurfer merged local-cfg put-fn]
         (when @show-map?
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
