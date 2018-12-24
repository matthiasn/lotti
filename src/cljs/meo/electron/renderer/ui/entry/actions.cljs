(ns meo.electron.renderer.ui.entry.actions
  (:require [meo.electron.renderer.ui.pomodoro :as p]
            [re-frame.core :refer [subscribe]]
            [meo.common.utils.parse :as up]
            [meo.electron.renderer.helpers :as h]
            [reagent.core :as r]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.common.utils.misc :as u]
            [clojure.set :as set]
            [taoensso.timbre :refer-macros [info]]
            [cljs.pprint :as pp]))

(defn trash-icon [trash-fn]
  (let [local (r/atom {:visible false})
        toggle-visible (fn [_]
                         (swap! local update-in [:visible] not)
                         (.setTimeout js/window
                                      #(swap! local assoc-in [:visible] false)
                                      5000))]
    (fn [trash-fn]
      [:span.delete-btn
       [:i.fa.fa-trash-alt.toggle {:on-click toggle-visible}]
       (when (:visible @local)
         [:span.warn.delete
          {:on-click trash-fn}
          [:i.far.fa-trash-alt] " are you sure?"])])))

(defn edit-icon
  "Renders an edit icon, which transforms into a warning button that needs to be
   clicked again for actually discarding changes. This label is a little to the
   right, so it can't be clicked accidentally, and disappears again within 5
   seconds."
  [toggle-edit edit-mode? entry]
  (let [clicked (r/atom false)
        guarded-edit-fn (fn [_ev]
                          (swap! clicked not)
                          (.setTimeout js/window #(reset! clicked false) 25000))]
    (fn [toggle-edit edit-mode? entry]
      (when edit-mode?
        [:span.delete-btn
         [:i.fa.fa-edit.toggle {:on-click guarded-edit-fn}]
         (when @clicked
           (let [click #(do (toggle-edit)
                            (swap! clicked not)
                            (info "Discarding local changes:\n"
                                  (with-out-str (pp/pprint entry))))]
             [:span.warn.discard {:on-click click}
              [:i.far.fa-trash-alt] " discard changes?"]))]))))

(defn drop-linked-fn
  "Creates handler function for drop event, which takes the timestamp of the
   currently dragged element and links that entry to the one onto which it is
   dropped."
  [entry cfg put-fn]
  (fn [_ev]
    (if (= :story (:entry_type entry))
      ; assign story
      (let [dropped (:currently-dragged @cfg)
            ts (:timestamp dropped)
            story (:timestamp entry)
            updated (merge (-> dropped
                               (update-in [:linked_stories] #(set/union #{story} %))
                               (assoc-in [:primary_story] story))
                           (up/parse-entry (:md dropped)))]
        (when (and ts (not= ts story))
          (put-fn [:entry/update updated])))
      ; link two entries
      (let [dropped (:currently-dragged @cfg)
            ts (:timestamp dropped)
            story (or (-> entry :story :timestamp)
                      (-> dropped :story :timestamp))
            updated (update-in entry [:linked_entries] #(set (conj % ts)))
            updated (assoc-in updated [:primary_story] story)]
        (when (and ts (not= ts (:timestamp updated)))
          (put-fn [:entry/update (u/clean-entry updated)]))))))

(defn drop-on-briefing [entry cfg put-fn]
  (fn [_ev]
    (let [dropped (:currently-dragged @cfg)
          ts (:timestamp dropped)
          updated (update-in entry [:linked_entries] #(set (conj % ts)))
          dropped-updated (update-in dropped [:perm_tags] #(set/union % #{"#task"}))]
      (when (and ts (not= ts (:timestamp updated)))
        (put-fn [:entry/update (u/clean-entry updated)])
        (put-fn [:entry/update (u/clean-entry dropped-updated)])))))

(defn drag-start-fn [entry put-fn]
  (fn [ev]
    (let [dt (.-dataTransfer ev)]
      (put-fn [:cmd/set-dragged entry])
      (aset dt "effectAllowed" "move")
      (aset dt "dropEffect" "link"))))

(defn entry-actions
  "Entry-related action buttons. Hidden by default, become visible when mouse
   hovers over element, stays visible for a little while after mose leaves."
  [entry local put-fn edit-mode? toggle-edit local-cfg]
  (let [visible (r/atom false)
        backend-cfg (subscribe [:backend-cfg])
        ts (:timestamp entry)
        hide-fn (fn [_ev] (.setTimeout js/window #(reset! visible false) 60000))
        query-id (:query-id local-cfg)
        tab-group (:tab-group local-cfg)
        story-name (get-in entry [:story :story_name])
        text (eu/first-line entry)
        toggle-map #(put-fn [:cmd/toggle
                             {:timestamp ts
                              :path      [:cfg :show-maps-for]}])
        show-hide-comments #(put-fn [:cmd/assoc-in
                                     {:path  [:cfg :show-comments-for ts]
                                      :value %}])
        show-comments #(show-hide-comments query-id)
        create-comment (h/new-entry put-fn {:comment_for ts} show-comments)
        new-pomodoro (fn [_ev]
                       (let [new-entry-fn (h/new-entry put-fn
                                                       (p/pomodoro-defaults ts)
                                                       show-comments)
                             new-entry (new-entry-fn)]
                         (put-fn [:cmd/schedule-new
                                  {:message [:cmd/pomodoro-start new-entry]
                                   :timeout 1000}])))
        trash-entry (fn [_]
                      (put-fn [:search/remove-all
                               {:story       (get-in entry [:story :timestamp])
                                :search-text (str ts)}])
                      (if edit-mode?
                        (put-fn [:entry/remove-local {:timestamp ts}])
                        (put-fn [:entry/trash entry])))
        move-over (fn [_]
                    (put-fn [:search/remove-all
                             {:story       (get-in entry [:story :timestamp])
                              :search-text (str ts)}])
                    ((up/add-search {:tab-group    tab-group
                                     :story-name   story-name
                                     :first-line   text
                                     :query-string ts}
                                    put-fn)))
        mouse-enter #(reset! visible true)
        toggle-album #(put-fn [:entry/update
                               (update entry :perm_tags (fn [pt]
                                                          (if (contains? pt "#album")
                                                            (disj pt "#album")
                                                            (conj pt "#album"))))])
        toggle-debug #(swap! local update-in [:debug] not)]
    (fn entry-actions-render [entry local put-fn edit-mode? toggle-edit local-cfg]
      (let [{:keys [latitude longitude]} entry
            map? (and latitude longitude
                      (not (and (zero? latitude)
                                (zero? longitude))))
            prev-saved? (or (:last_saved entry) (< ts 1479563777132))
            comment? (:comment_for entry)
            star-entry #(put-fn [:entry/update-local (update-in entry [:starred] not)])
            flag-entry #(put-fn [:entry/update-local (update-in entry [:flagged] not)])
            starred (:starred entry)
            flagged (:flagged entry)
            album (contains? (set/union (set (:tags entry))
                                        (set (:perm_tags entry)))
                             "#album")]
        [:div.actions {:on-mouse-enter mouse-enter
                       :on-mouse-leave hide-fn}
         [:div.items                                        ;{:style {:opacity opacity}}
          (when map? [:i.fa.fa-map.toggle {:on-click toggle-map}])
          (when prev-saved? [edit-icon toggle-edit edit-mode? entry])
          (when-not comment? [:i.fa.fa-stopwatch.toggle {:on-click new-pomodoro}])
          (when-not comment? [:i.fa-images.toggle {:class    (if album "album-activated fas" "fa")
                                                   :on-click toggle-album}])
          (when-not comment?
            [:i.fa.fa-comment.toggle {:on-click create-comment}])
          (when (and (contains? #{:left :right} tab-group) (not comment?))
            [:i.fa.toggle.far
             {:class    (if (= tab-group :left)
                          "fa-arrow-alt-from-left"
                          "fa-arrow-alt-from-right")
              :on-click move-over}])
          [trash-icon trash-entry]
          (when (or (contains? (:capabilities @backend-cfg) :debug)
                    h/repo-dir)
            [:i.fa.fa-bug.toggle {:on-click toggle-debug}])]
         [:i.fa.toggle
          {:on-click star-entry
           :class    (if starred "fa-star starred" "fa-star")}]
         [:i.fa.toggle
          {:on-click flag-entry
           :class    (if flagged "fa-flag flagged" "fa-flag")}]]))))

(defn briefing-actions [ts put-fn]
  (let [create-comment (fn [_ev]
                         (let [create (h/new-entry put-fn {:comment_for ts})
                               new-entry (create)]
                           (info "created comment" new-entry)
                           (put-fn [:entry/update new-entry])))
        new-pomodoro (fn [_ev]
                       (let [create (h/new-entry put-fn (p/pomodoro-defaults ts))
                             new-entry (create)]
                         (info "new-pomodoro" new-entry)
                         (put-fn [:cmd/schedule-new
                                  {:message [:cmd/pomodoro-start new-entry]
                                   :timeout 1000}])))]
    [:div.actions {}
     [:div.items
      [:i.fa.fa-stopwatch.toggle {:on-click new-pomodoro}]
      [:i.fa.fa-comment.toggle {:on-click create-comment}]]]))
