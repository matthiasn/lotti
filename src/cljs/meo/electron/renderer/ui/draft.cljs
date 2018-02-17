(ns meo.electron.renderer.ui.draft
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]
            [taoensso.timbre :refer-macros [info debug]]
            [meo.common.utils.parse :as p]
            [meo.common.utils.misc :as u]
            [draft-js :as Draft]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.electron.renderer.ui.entry.pomodoro :as pomo]))

(defn editor-state-from-text [text]
  (let [content-from-text (.createFromText Draft.ContentState text)]
    (.createWithContent Draft.EditorState content-from-text)))

(defn editor-state-from-raw [editor-state]
  (let [content-from-raw (.convertFromRaw Draft editor-state)]
    (.createWithContent Draft.EditorState content-from-raw)))

(defn story-mapper [[ts story]]
  (when-let [story-name (:story-name story)]
    {:name story-name
     :id   ts}))

(defn on-editor-change [update-cb]
  (fn [new-state]
    (let [current-content (.getCurrentContent new-state)
          plain (.getPlainText current-content)
          raw-content (.convertToRaw Draft current-content)
          via-json (.parse js/JSON (.stringify js/JSON raw-content))
          new-state (js->clj via-json :keywordize-keys true)]
      (update-cb plain new-state))))

(defn adapt-react-class [cls]
  (r/adapt-react-class (aget js/window "deps" cls "default")))

(defn entry-stories [editor-state]
  (->> editor-state
       :entityMap
       vals
       (filter #(= (:type %) "$mention"))
       (map #(-> % :data :mention :id))
       (map #(when % (js/parseInt %)))))

(defn draft-search-field [_editor-state update-cb]
  (let [editor (adapt-react-class "SearchFieldEditor")
        options (subscribe [:options])
        sorted-stories (reaction (:sorted-stories @options))
        stories-list (reaction (filter identity (map story-mapper @sorted-stories)))
        cfg (subscribe [:cfg])
        mentions (reaction (map (fn [m] {:name m}) (:mentions @options)))
        hashtags (reaction
                   (let [show-pvt? (:show-pvt @cfg)
                         hashtags (:hashtags @options)
                         pvt-hashtags (:pvt-hashtags @options)
                         hashtags (if show-pvt?
                                    (concat hashtags pvt-hashtags)
                                    hashtags)]
                     (map (fn [h] {:name h}) hashtags)))
        on-change (on-editor-change update-cb)]
    (fn [editor-state _send-fn]
      [editor {:editorState editor-state
               :mentions    @mentions
               :hashtags    @hashtags
               :stories     @stories-list
               :onChange    on-change}])))

(defn draft-text-editor [md update-cb save-fn start-fn small-img changed]
  (let [editor (adapt-react-class "EntryTextEditor")
        options (subscribe [:options])
        sorted-stories (reaction (:sorted-stories @options))
        stories-list (reaction (filter identity (map story-mapper @sorted-stories)))
        cfg (subscribe [:cfg])
        mentions (reaction (map (fn [m] {:name m}) (:mentions @options)))
        hashtags (reaction
                   (let [show-pvt? (:show-pvt @cfg)
                         hashtags (:hashtags @options)
                         pvt-hashtags (:pvt-hashtags @options)
                         hashtags (if show-pvt?
                                    (concat hashtags pvt-hashtags)
                                    hashtags)]
                     (map (fn [h] {:name h}) hashtags)))]
    (fn [md update-cb save-fn start-fn small-img changed]
      [editor {:md       md
               :changed  changed
               :mentions @mentions
               :hashtags @hashtags
               :stories  @stories-list
               :saveFn   save-fn
               :startFn  start-fn
               :smallImg small-img
               :onChange update-cb}])))

(defn entry-editor [entry put-fn]
  (let [ts (:timestamp @entry)
        {:keys [entry edit-mode unsaved]} (eu/entry-reaction ts)
        editor-cb (fn [md plain]
                    (when-not (= md (:md @entry))
                      (let [updated (merge
                                      @entry
                                      (p/parse-entry md)
                                      {:text plain})]
                        (when (:timestamp updated)
                          (put-fn [:entry/update-local updated])))))]
    (fn [entry put-fn]
      (let [latest-entry (dissoc @entry :comments)
            edit-mode? @edit-mode
            save-fn (fn [_ev]
                      (let [cleaned (u/clean-entry latest-entry)
                            updated (if (= (:entry-type entry) :pomodoro)
                                      (assoc-in cleaned [:pomodoro-running] false)
                                      cleaned)]
                        (when (:pomodoro-running @entry)
                          (put-fn [:window/progress {:v 0}])
                          (put-fn [:blink/busy {:color :green}])
                          (put-fn [:cmd/pomodoro-stop updated]))
                        (put-fn [:entry/update-local updated])
                        (put-fn [:entry/update updated])))
            start-fn #(when (= (:entry-type latest-entry) :pomodoro)
                        (put-fn [:cmd/pomodoro-start latest-entry]))
            small-img (fn [smaller]
                        (let [img-size (:img-size @entry 50)
                              img-size (if smaller (- img-size 10) (+ img-size 10))
                              updated (assoc-in @entry [:img-size] img-size)]
                          (when (and (pos? img-size)
                                     (< img-size 101)
                                     (:timestamp updated))
                            (put-fn [:entry/update-local updated]))))
            md (or (:md @entry) "")]
        [:div
         [draft-text-editor md editor-cb save-fn start-fn small-img @unsaved]
         [:div.entry-footer
          [:div.save
           (when @unsaved
             [:span.not-saved {:on-click save-fn}
              [:i.far.fa-save] " save"])]
          [pomo/pomodoro-header entry edit-mode? put-fn]]]))))
