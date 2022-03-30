(ns meins.electron.renderer.ui.entry.actions
  (:require [cljs.pprint :as pp]
            [clojure.set :as set]
            [meins.common.utils.misc :as u]
            [meins.common.utils.parse :as up]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [meins.electron.renderer.ui.pomodoro :as p]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [info]]))

(defn trash-icon [_]
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
  [_ _ _]
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
  [entry cfg]
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
          (emit [:entry/update updated])))
      ; link two entries
      (let [dropped (:currently-dragged @cfg)
            dropped (update dropped :tags disj "#import")
            ts (:timestamp dropped)
            story (or (-> entry :story :timestamp)
                      (-> dropped :story :timestamp))
            updated (update-in entry [:linked_entries] #(set (conj % ts)))
            updated (if (and (:img_file dropped)
                             (not (:img_file updated)))
                      (update-in updated [:perm_tags] #(set (conj % "#album")))
                      updated)
            updated (assoc-in updated [:primary_story] story)]
        (when (and ts (not= ts (:timestamp updated)))
          (emit [:entry/update (u/clean-entry updated)]))
        (if (and story (not (:primary_story dropped)))
          (let [updated (assoc-in dropped [:primary_story] story)]
            (emit [:entry/update (u/clean-entry updated)]))
          (emit [:entry/update (u/clean-entry dropped)]))))))

(defn drop-on-briefing [entry cfg]
  (fn [_ev]
    (let [dropped (:currently-dragged @cfg)
          ts (:timestamp dropped)
          updated (update-in entry [:linked_entries] #(set (conj % ts)))
          dropped-updated (update-in dropped [:perm_tags] #(set/union % #{"#task"}))]
      (when (and ts (not= ts (:timestamp updated)))
        (emit [:entry/update (u/clean-entry updated)])
        (emit [:entry/update (u/clean-entry dropped-updated)])))))

(defn drag-start-fn [entry]
  (fn [ev]
    (let [dt (.-dataTransfer ev)]
      (emit [:cmd/set-dragged entry])
      (aset dt "effectAllowed" "move")
      (aset dt "dropEffect" "link"))))

(defn cf-tag-select [entry]
  (let [show-pvt (subscribe [:show-pvt])
        local (r/atom {:search "" :show false :idx 0})
        active-filter (fn [[_tag x]] (:active x))
        backend-cfg (subscribe [:backend-cfg])
        cfg (reaction (:custom-fields @backend-cfg))
        indexed (reaction
                  (->> (sort-by #(u/lower-case (first %)) @cfg)
                       (filter (fn [[_tag x]]
                                 (if @show-pvt true (not (:pvt x)))))
                       (filter active-filter)
                       (map-indexed (fn [i v] [i v]))))
        assign-tag (fn [tag]
                     (let [pt (set (:perm_tags entry))
                           toggle-tag #(if (contains? pt tag)
                                         (disj (set %) tag)
                                         (conj (set %) tag))
                           updated (update-in entry [:perm_tags] toggle-tag)]
                       (swap! local assoc-in [:show] false)
                       (emit [:entry/update-local updated])))
        match (fn [[_i [tag _x]]]
                (h/str-contains-lc? tag (:search @local "")))
        keydown (fn [ev]
                  (let [key-code (.. ev -keyCode)
                        matched (filter match @indexed)
                        idx-inc (fn [i]
                                  (let [idxs (map first matched)
                                        ni (first (drop-while #(<= % i) idxs))]
                                    (if ni ni (apply min idxs))))
                        idx-dec (fn [i]
                                  (let [idxs (map first matched)
                                        ni (first (drop-while #(>= % i) (reverse idxs)))]
                                    (if ni ni (apply max idxs))))]
                    (when (:show @local)
                      (when (= key-code 27)
                        (swap! local assoc-in [:show] false))
                      (when (= key-code 40)
                        (swap! local update-in [:idx] idx-inc))
                      (when (= key-code 38)
                        (swap! local update-in [:idx] idx-dec))
                      (when (= key-code 13)
                        (assign-tag (first (second (nth @indexed (:idx @local)))))))
                    (.stopPropagation ev)))
        start-watch #(.addEventListener js/document "keydown" keydown)
        stop-watch #(.removeEventListener js/document "keydown" keydown)]
    (fn story-select-filter-render [entry]
      (let [linked-story (get-in entry [:story :timestamp])
            input-fn (fn [ev]
                       (let [s (-> ev .-nativeEvent .-target .-value)]
                         (swap! local assoc-in [:idx] 0)
                         (swap! local assoc-in [:search] s)))
            mouse-leave (fn [_]
                          (let [t (js/setTimeout
                                    #(swap! local assoc-in [:show] false)
                                    2000)]
                            (swap! local assoc-in [:timeout] t)
                            (stop-watch)))
            mouse-enter #(when-let [t (:timeout @local)] (js/clearTimeout t))
            toggle-visible (fn [_]
                             (swap! local update-in [:show] not)
                             (if (:show @local) (start-watch) (stop-watch)))
            icon-cls (str (when (:show @local) "show"))
            indexed @indexed]
        [:span.cf-hashtag-select
         [:span
          [:i.fa.fa-hashtag.toggle
           (merge
             {:on-click toggle-visible
              :class    (str icon-cls)})]]
         (when (:show @local)
           (let [curr-idx (:idx @local)
                 items (take 20 (filter match indexed))]
             [:div.story-search {:on-mouse-leave mouse-leave
                                 :on-mouse-enter mouse-enter}
              [:div
               [:i.fal.fa-search]
               [:input {:type       :text
                        :on-change  input-fn
                        :auto-focus true
                        :value      (:search @local)}]]
              [:table
               [:tbody
                (doall
                  (for [[idx [tag entry]] items]
                    (let [active (= linked-story (:timestamp entry))
                          cls (cond active "current"
                                    (= idx curr-idx) "idx"
                                    :else "")
                          click #(assign-tag tag)]
                      ^{:key (:timestamp entry)}
                      [:tr {:on-click click}
                       [:td {:class cls}
                        tag]])))]]]))]))))

(defn entry-actions
  "Entry-related action buttons. Hidden by default, become visible when mouse
   hovers over element, stays visible for a little while after mose leaves."
  [entry _local edit-mode? _toggle-edit local-cfg]
  (let [visible (r/atom false)
        backend-cfg (subscribe [:backend-cfg])
        ts (:timestamp entry)
        hide-fn (fn [_ev] (.setTimeout js/window #(reset! visible false) 60000))
        query-id (:query-id local-cfg)
        tab-group (:tab-group local-cfg)
        story-name (get-in entry [:story :story_name])
        text (eu/first-line entry)
        toggle-map #(emit [:cmd/toggle
                           {:timestamp ts
                            :path      [:cfg :show-maps-for]}])
        show-hide-comments #(emit [:cmd/assoc-in
                                   {:path  [:cfg :show-comments-for ts]
                                    :value %}])
        show-comments #(show-hide-comments query-id)
        create-comment (h/new-entry {:comment_for ts} show-comments)
        new-pomodoro (fn [_ev]
                       (let [new-entry-fn (h/new-entry (p/pomodoro-defaults ts)
                                                       show-comments)
                             new-entry (new-entry-fn)]
                         (emit [:schedule/new
                                {:message [:cmd/pomodoro-start new-entry]
                                 :timeout 1000}])))
        trash-entry (fn [_]
                      (emit [:search/remove-all
                             {:story       (get-in entry [:story :timestamp])
                              :search-text (str ts)}])
                      (if edit-mode?
                        (emit [:entry/remove-local {:timestamp ts}])
                        (emit [:entry/trash entry])))
        move-over (fn [_]
                    (emit [:search/remove-all
                           {:story       (get-in entry [:story :timestamp])
                            :search-text (str ts)}])
                    ((up/add-search {:tab-group    tab-group
                                     :story-name   story-name
                                     :first-line   text
                                     :query-string ts}
                                    emit)))
        mouse-enter #(reset! visible true)]
    (fn entry-actions-render [entry local edit-mode? toggle-edit local-cfg]
      (let [toggle-debug (fn [_] (swap! local update-in [:debug] not))
            {:keys [latitude longitude]} entry
            map? (and latitude longitude
                      (not (and (zero? latitude)
                                (zero? longitude)))
                      (not (:hide-map local-cfg)))
            prev-saved? (or (:last_saved entry) (< ts 1479563777132))
            comment? (:comment_for entry)
            star-entry #(emit [:entry/update-local (update-in entry [:starred] not)])
            flag-entry #(emit [:entry/update-local (update-in entry [:flagged] not)])
            starred (:starred entry)
            flagged (:flagged entry)]
        [:div.actions {:on-mouse-enter mouse-enter
                       :on-mouse-leave hide-fn}
         [:div.items
          [cf-tag-select entry]
          (when map? [:i.fa.fa-map.toggle {:on-click toggle-map}])
          (when prev-saved? [edit-icon toggle-edit edit-mode? entry])
          (when-not comment? [:i.fa.fa-stopwatch.toggle {:on-click new-pomodoro}])
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
                    h/repo-dir
                    true)
            [:i.fa.fa-bug.toggle {:on-click toggle-debug}])]
         [:i.fa.toggle
          {:on-click star-entry
           :class    (if starred "fa-star starred" "fa-star")}]
         [:i.fa.toggle
          {:on-click flag-entry
           :class    (if flagged "fa-flag flagged" "fa-flag")}]]))))
