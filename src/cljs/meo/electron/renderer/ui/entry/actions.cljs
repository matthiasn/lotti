(ns meo.electron.renderer.ui.entry.actions
  (:require [meo.electron.renderer.ui.pomodoro :as p]
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
                          (.setTimeout js/window #(reset! clicked false) 5000))]
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
                               (update-in [:linked-stories] #(set/union #{story} %))
                               (assoc-in [:primary_story] story))
                           (up/parse-entry (:md dropped)))]
        (when (and ts (not= ts story))
          (put-fn [:entry/update updated])))
      ; link two entries
      (let [dropped (:currently-dragged @cfg)
            ts (:timestamp dropped)
            updated (update-in entry [:linked-entries] #(set (conj % ts)))]
        (when (and ts (not= ts (:timestamp updated)))
          (put-fn [:entry/update (u/clean-entry updated)]))))))

(defn drag-start-fn [entry put-fn]
  (fn [ev]
    (let [dt (.-dataTransfer ev)]
      (put-fn [:cmd/set-dragged entry])
      (aset dt "effectAllowed" "move")
      (aset dt "dropEffect" "link"))))

(defn new-link
  "Renders input for adding link entry."
  [entry put-fn create-linked-entry]
  (let [local (r/atom {:visible false})
        toggle-visible (fn [_]
                         (swap! local update-in [:visible] not)
                         (.setTimeout js/window
                                      #(swap! local assoc-in [:visible] false)
                                      5000))
        on-drag-start (drag-start-fn entry put-fn)]
    (fn [entry put-fn create-linked-entry]
      [:span.new-link-btn
       [:i.fa.fa-link.toggle {:on-click      toggle-visible
                              :draggable     true
                              :on-drag-start on-drag-start}]
       (when (:visible @local)
         [:span.new-link
          {:on-click #(do (create-linked-entry) (toggle-visible %))}
          [:i.fas.fa-plus-square] "add linked"])])))

(defn entry-actions
  "Entry-related action buttons. Hidden by default, become visible when mouse
   hovers over element, stays visible for a little while after mose leaves."
  [entry put-fn edit-mode? toggle-edit local-cfg]
  (let [visible (r/atom false)
        ts (:timestamp entry)
        hide-fn (fn [_ev] (.setTimeout js/window #(reset! visible false) 60000))
        query-id (:query-id local-cfg)
        tab-group (:tab-group local-cfg)
        toggle-map #(put-fn [:cmd/toggle
                             {:timestamp ts
                              :path      [:cfg :show-maps-for]}])
        show-hide-comments #(put-fn [:cmd/assoc-in
                                     {:path  [:cfg :show-comments-for ts]
                                      :value %}])
        show-comments #(show-hide-comments query-id)
        create-comment (h/new-entry put-fn {:comment_for ts} show-comments)
        screenshot #(put-fn [:screenshot/take {:comment_for ts}])
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
        open-external (up/add-search ts tab-group put-fn)
        star-entry #(put-fn [:entry/update-local (update-in entry [:starred] not)])
        mouse-enter #(reset! visible true)]
    (fn entry-actions-render [entry put-fn edit-mode? toggle-edit local-cfg]
      (let [map? (:latitude entry)
            prev-saved? (or (:last_saved entry) (< ts 1479563777132))
            comment? (:comment_for entry)
            starred (:starred entry)
            story (get-in entry [:story :timestamp])
            open-new (fn [x]
                       (put-fn [:search/add
                                {:tab-group (if (= tab-group :left) :right :left)
                                 :query     (up/parse-search (:timestamp x))}]))
            create-linked (h/new-entry put-fn
                                       {:linked_entries #{ts}
                                        :primary_story  story
                                        :linked_stories #{story}}
                                       open-new)]
        [:div.actions {:on-mouse-enter mouse-enter
                       :on-mouse-leave hide-fn}
         [:div.items {:style {:opacity (if (or edit-mode? @visible) 1 0)}}
          (when map? [:i.fa.fa-map.toggle {:on-click toggle-map}])
          (when prev-saved? [edit-icon toggle-edit edit-mode? entry])
          (when-not comment? [:i.fa.fa-stopwatch.toggle {:on-click new-pomodoro}])
          (when-not comment?
            [:i.fa.fa-comment.toggle {:on-click create-comment}])
          #_
          (when-not comment?
            [:i.fa.fa-desktop.toggle {:on-click screenshot}])
          (when (and (not comment?) prev-saved?)
            [:i.fa.fa-external-link-alt.toggle {:on-click open-external}])
          (when-not comment? [new-link entry put-fn create-linked])
          [trash-icon trash-entry]]
         [:i.fa.toggle
          {:on-click star-entry
           :style    {:opacity (if (or starred edit-mode? @visible) 1 0)}
           :class    (if starred "fa-star starred" "fa-star")}]]))))

(defn briefing-actions [ts put-fn]
  (let [open-new (fn [x]
                   (put-fn [:search/add
                            {:tab-group :right
                             :query     (up/parse-search (:timestamp x))}]))
        create-linked-entry (h/new-entry put-fn {:linked_entries #{ts}
                                                 :starred        true
                                                 :perm_tags      #{"#task"}}
                                         open-new)
        create-comment (fn [_ev]
                         (let [create (h/new-entry put-fn {:comment_for ts} nil)
                               new-entry (create)]
                           (info "created comment" new-entry)
                           (put-fn [:entry/update new-entry])))
        new-pomodoro (fn [_ev]
                       (let [create (h/new-entry
                                      put-fn (p/pomodoro-defaults ts) nil)
                             new-entry (create)]
                         (info "new-pomodoro" new-entry)
                         (put-fn [:cmd/schedule-new
                                  {:message [:cmd/pomodoro-start new-entry]
                                   :timeout 1000}])))]
    [:div.actions {}
     [:div.items
      [:i.fa.fa-stopwatch.toggle {:on-click new-pomodoro}]
      [:i.fa.fa-comment.toggle {:on-click create-comment}]
      [:i.fa.fa-plus-square.toggle
       {:on-click #(create-linked-entry)}]]]))
