(ns meo.electron.renderer.ui.entry.story
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]
            [taoensso.timbre :refer [info error debug]]
            [meo.electron.renderer.helpers :as h]
            [clojure.set :as set]))

(defn editable-field [on-input-fn on-keydown-fn text]
  (fn [_ _ _]
    [:div.story-edit-field
     {:content-editable true
      :on-input         on-input-fn
      :on-key-down      on-keydown-fn}
     text]))

(defn keydown-fn [entry k put-fn]
  (fn [ev]
    (let [text (aget ev "target" "innerText")
          updated (assoc-in entry [k] text)
          key-code (.. ev -keyCode)
          meta-key (.. ev -metaKey)]
      (when (and meta-key (= key-code 83))                  ; CMD-s pressed
        (put-fn [:entry/update updated])
        (.preventDefault ev)))))

(defn input-fn [entry k put-fn]
  (fn [ev]
    (let [text (aget ev "target" "innerText")
          updated (assoc-in entry [k] text)]
      (put-fn [:entry/update-local updated]))))

(defn story-name-field
  "Renders editable field for story name when the entry is of type :story.
   Updates local entry on input, and saves the entry when CMD-S is pressed."
  [entry edit-mode? put-fn]
  (when (= (:entry-type entry) :story)
    (let [on-input-fn (input-fn entry :story-name put-fn)
          on-keydown-fn (keydown-fn entry :story-name put-fn)]
      (if edit-mode?
        [:div.story
         [:label "Story:"]
         [editable-field on-input-fn on-keydown-fn (:story-name entry)]]
        [:h2 "Story: " (:story-name entry)]))))

(defn saga-name-field
  "Renders editable field for saga name when the entry is of type :saga.
   Updates local entry on input, and saves the entry when CMD-S is pressed."
  [entry edit-mode? put-fn]
  (when (= (:entry-type entry) :saga)
    (let [on-input-fn (input-fn entry :saga-name put-fn)
          on-keydown-fn (keydown-fn entry :saga-name put-fn)]
      (if edit-mode?
        [:div.story
         [:label "Saga:"]
         [editable-field on-input-fn on-keydown-fn (:saga-name entry)]]
        [:h2 "Saga: " (:saga-name entry)]))))

(defn saga-select
  "In edit mode, allow editing of story, otherwise show story name."
  [entry put-fn edit-mode?]
  (let [options (subscribe [:options])
        sagas (subscribe [:sagas])
        sorted-sagas (reaction (:sorted-sagas @options))
        ts (:timestamp entry)
        new-entries (subscribe [:new-entries])
        select-handler
        (fn [ev]
          (let [selected (js/parseInt (-> ev .-nativeEvent .-target .-value))
                updated (-> (get-in @new-entries [ts])
                            (assoc-in [:linked-saga] selected))]
            (put-fn [:entry/update-local updated])))]
    (fn story-select-render [entry put-fn edit-mode?]
      (let [linked-saga (:linked-saga entry)
            entry-type (:entry-type entry)]
        (when (= entry-type :story)
          (if edit-mode?
            (when-not (:comment-for entry)
              [:div.story
               [:label "Saga:"]
               [:select {:value     (or linked-saga "")
                         :on-change select-handler}
                [:option {:value ""} "no saga selected"]
                (for [[id saga] @sorted-sagas]
                  (let [saga-name (:saga-name saga)]
                    ^{:key (str ts saga-name)}
                    [:option {:value id} saga-name]))]])
            (when linked-saga
              [:div.story "Saga: " (:saga-name (get @sagas linked-saga))])))))))

(defn merged-stories [predictions stories]
  (let [ranked (:ranked predictions)
        predictions-set (set ranked)
        stories-set (set stories)
        without-predictions (set/difference stories-set predictions-set)]
    (if (seq ranked)
      (concat ranked without-predictions)
      stories)))

(defn story-select [entry put-fn]
  (let [stories (subscribe [:stories])
        ts (:timestamp @entry)
        story-predict (subscribe [:story-predict])
        predictions (reaction (get-in @story-predict [ts]))
        linked-story (reaction (:primary-story @entry))
        story-name (reaction (:story-name (get @stories @linked-story)))
        local (r/atom {:search "" :show false})
        input-fn (fn [ev]
                   (let [s (-> ev .-nativeEvent .-target .-value)]
                     (swap! local assoc-in [:search] s)))
        assign-story (fn [story]
                       (let [ts (:timestamp story)
                             updated (assoc-in @entry [:primary-story] ts)]
                         (swap! local assoc-in [:show] false)
                         (put-fn [:entry/update-local updated])))]
    (fn story-select-filter-render [entry put-fn]
      (let [linked-story @linked-story]
        (when-not (or (:comment-for @entry)
                      (= (:entry-type @entry) :story))
          [:div.story-select
           (if (:show @local)
             (let [story-tss (merged-stories @predictions (keys @stories))
                   stories (map #(get @stories %) story-tss)
                   s (:search @local)
                   filter-fn #(h/str-contains-lc? (:story-name %) s)
                   stories (vec (filter filter-fn stories))]
               (when-let [p (:p-1 @predictions)] (info p))
               [:div.story-search {:on-mouse-leave #(swap! local assoc-in [:show] false)}
                [:div
                 [:i.fal.fa-search]
                 [:input {:type       :text
                          :on-change  input-fn
                          :auto-focus true
                          :value      (:search @local)}]]
                [:table
                 [:tbody
                  (for [story (take 10 stories)]
                    (let [active (= linked-story (:timestamp story))]
                      ^{:key (:timestamp story)}
                      [:tr {:on-click #(assign-story story)}
                       [:td {:class (when active "current")}
                        (:story-name story)]]))]]])
             [:div.story
              [:i.fal.fa-book {:on-click #(swap! local update-in [:show] not)
                               :class    (str (when (and
                                                      (not (:primary-story @entry))
                                                      @predictions)
                                                "predicted ")
                                              (when (:show @local) "show"))}]
              @story-name])])))))
