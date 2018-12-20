(ns meo.electron.renderer.ui.entry.story
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]
            [taoensso.timbre :refer [info error debug]]
            [meo.electron.renderer.helpers :as h]
            [clojure.set :as set]
            [react-color :as react-color]
            [meo.common.utils.parse :as up]
            [meo.electron.renderer.ui.ui-components :as uc]
            [meo.electron.renderer.ui.charts.common :as cc]))

(defn editable-field [_ _ text]
  (fn [on-input-fn on-keydown-fn _]
    [:div.story-edit-field
     {:content-editable true
      :on-input         on-input-fn
      :on-key-down      on-keydown-fn}
     text]))

(defn input-fn [entry k put-fn]
  (fn [ev]
    (let [text (aget ev "target" "innerText")
          updated (assoc-in entry [k] text)]
      (put-fn [:entry/update-local updated]))))

(declare saga-select)

(def chrome-picker (r/adapt-react-class react-color/ChromePicker))

(defn color-picker [entry path label put-fn]
  (let [set-color (fn [data]
                    (let [hex (aget data "hex")
                          updated (assoc-in entry path hex)]
                      (put-fn [:entry/update-local updated])))]
    [:div.row
     [:label.wide label]
     [chrome-picker {:disableAlpha     true
                     :color            (get-in entry path "#ccc")
                     :onChangeComplete set-color}]]))

(defn story-form
  "Renders editable field for story name when the entry is of type :story.
   Updates local entry on input, and saves the entry when CMD-S is pressed."
  [entry put-fn]
  (when (= (:entry_type entry) :story)
    (let [on-input-fn (input-fn entry :story_name put-fn)
          on-keydown-fn (h/keydown-fn entry :story_name put-fn)
          sw-common {:entry entry :put-fn put-fn :msg-type :entry/update}
          font-color-path [:story_cfg :font_color]
          badge-color-path [:story_cfg :badge_color]]
      [:div.story
       [saga-select entry put-fn]
       [:label "Story Name:"]
       [:div.story-edit-field
        {:content-editable true
         :on-input         on-input-fn
         :on-key-down      on-keydown-fn}
        (:story_name entry)]
       [:div.row
        [:label "Active? "]
        [uc/switch (merge sw-common {:path [:story_cfg :active]})]]
       [:div.row
        [:label "Private? "]
        [uc/switch (merge sw-common {:path [:story_cfg :pvt]})]]
       [color-picker entry font-color-path "Text Color:" put-fn]
       [:div.badge
        [:span.story-badge
         {:style {:background-color (get-in entry badge-color-path :white)
                  :color            (get-in entry font-color-path :black)}}
         (:story_name entry)]]
       [color-picker entry badge-color-path "Badge Color:" put-fn]])))

(defn saga-name-field
  "Renders editable field for saga name when the entry is of type :saga.
   Updates local entry on input, and saves the entry when CMD-S is pressed."
  [entry edit-mode? put-fn]
  (when (= (:entry_type entry) :saga)
    (let [on-input-fn (input-fn entry :saga_name put-fn)
          on-keydown-fn (h/keydown-fn entry :saga_name put-fn)
          sw-common {:entry entry :put-fn put-fn :msg-type :entry/update}]
      [:div.story.saga
       [:label "Saga:"]
       [editable-field on-input-fn on-keydown-fn (:saga_name entry)]
       [:div.row
        [:label "Active? "]
        [uc/switch (merge sw-common {:path [:saga_cfg :active]})]]
       [:div.row
        [:label "Private? "]
        [uc/switch (merge sw-common {:path [:saga_cfg :pvt]})]]])))

(defn saga-select
  [entry put-fn]
  (let [sagas (subscribe [:sagas])
        ts (:timestamp entry)]
    (fn saga-select-render [entry put-fn]
      (let [linked-saga (:linked_saga entry)
            entry-type (:entry_type entry)
            select-handler
            (fn [ev]
              (let [selected (js/parseInt (-> ev .-nativeEvent .-target .-value))
                    updated (assoc-in entry [:linked_saga] selected)]
                (info "saga-select" selected)
                (put-fn [:entry/update-local updated])))]
        (when (= entry-type :story)
          (when-not (:comment_for entry)
            [:div.saga
             [:label "Saga:"]
             [:select {:value     (or linked-saga "")
                       :on-change select-handler}
              [:option {:value ""} "no saga selected"]
              (for [[id saga] (sort-by #(:saga_name (second %)) @sagas)]
                (let [saga-name (:saga_name saga)]
                  ^{:key (str ts saga-name)}
                  [:option {:value id} saga-name]))]]))))))

(defn merged-stories [predictions stories]
  (let [ranked (:ranked predictions)
        predictions-set (set ranked)
        stories-set (set stories)
        without-predictions (set/difference stories-set predictions-set)]
    (if (seq ranked)
      (concat ranked without-predictions)
      stories)))

(defn story-select [entry tab-group put-fn]
  (let [stories (subscribe [:stories])
        show-pvt (subscribe [:show-pvt])
        ts (:timestamp entry)
        local (r/atom {:search "" :show false :idx 0})
        story-predict (subscribe [:story-predict])
        predictions (reaction (get-in @story-predict [ts]))
        pvt-filter (fn [x] (if @show-pvt true (not (:pvt x))))
        active-filter (fn [x] (:active x))
        indexed (reaction
                  (let [s (:search @local "")
                        filter-fn #(h/str-contains-lc? (:story_name %) s)]
                    (->> (merged-stories @predictions (keys @stories))
                         (map #(get @stories %))
                         (filter filter-fn)
                         (filter pvt-filter)
                         (filter active-filter)
                         (map-indexed (fn [i v] [i v])))))
        assign-story (fn [story]
                       (swap! local assoc-in [:show] false)
                       (put-fn [:entry/update-merged
                                {:primary_story (:timestamp story)
                                 :timestamp     ts}]))
        keydown (fn [ev]
                  (let [key-code (.. ev -keyCode)
                        n (count @indexed)
                        idx-inc #(if (< % (dec n)) (inc %) 0)
                        idx-dec #(if (pos? %) (dec %) (dec n))]
                    (when (:show @local)
                      (when (= key-code 27)
                        (swap! local assoc-in [:show] false))
                      (when (= key-code 40)
                        (swap! local update-in [:idx] idx-inc))
                      (when (= key-code 38)
                        (swap! local update-in [:idx] idx-dec))
                      (when (= key-code 13)
                        (assign-story (second (nth @indexed (:idx @local))))))
                    (.stopPropagation ev)))
        start-watch #(.addEventListener js/document "keydown" keydown)
        stop-watch #(.removeEventListener js/document "keydown" keydown)]
    (fn story-select-filter-render [entry tab-group put-fn]
      (let [linked-story (get-in entry [:story :timestamp])
            story-name (get-in entry [:story :story_name])
            saga-name (get-in entry [:story :saga :saga_name])
            open-story (up/add-search {:tab-group    tab-group
                                       :story-name   story-name
                                       :first-line   story-name
                                       :query-string linked-story} put-fn)
            input-fn (fn [ev]
                       (let [s (-> ev .-nativeEvent .-target .-value)]
                         (swap! local assoc-in [:idx] 0)
                         (swap! local assoc-in [:search] s)))
            mouse-leave (fn [_]
                          (let [t (js/setTimeout
                                    #(swap! local assoc-in [:show] false)
                                    1500)]
                            (swap! local assoc-in [:timeout] t)
                            (stop-watch)))
            mouse-enter #(when-let [t (:timeout @local)] (js/clearTimeout t))
            toggle-visible (fn [_]
                             (swap! local update-in [:show] not)
                             (if (:show @local) (start-watch) (stop-watch)))
            icon-cls (str (when (and (not (:primary_story entry))
                                     @predictions)
                            "predicted ")
                          (when (:show @local) "show"))
            icon-color (cc/item-color story-name "light")
            font-color (cc/item-color story-name "dark")]
        (when-not (or (:comment_for entry)
                      (contains? #{:story :saga} (:entry_type entry)))
          [:div.story-select
           [:div.story.story-name
            (when story-name {:style {:background-color icon-color
                                      :color            font-color}})
            [:i.fal.fa-book
             (merge
               {:on-click toggle-visible
                :class    (str icon-cls)})]
            [:span {:on-click open-story}
             saga-name
             (when-not (empty? saga-name) ": ")
             story-name]]
           (when (:show @local)
             (let [curr-idx (:idx @local)]
               (when-let [p (:p-1 @predictions)] (info p))
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
                  (for [[idx story] (take 15 @indexed)]
                    (let [active (= linked-story (:timestamp story))
                          cls (cond active "current"
                                    (= idx curr-idx) "idx"
                                    :else "")
                          click #(assign-story story)
                          saga-name (:saga_name (:saga story))]
                      ^{:key (:timestamp story)}
                      [:tr {:on-click click}
                       [:td {:class cls}
                        saga-name (when-not (empty? saga-name) ": ")
                        (:story_name story)]]))]]]))])))))
