(ns meo.electron.renderer.ui.draft
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]
            [taoensso.timbre :refer-macros [info debug]]
            [meo.common.utils.parse :as p]
            [meo.common.utils.misc :as u]
            [draft-js :as Draft]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.electron.renderer.ui.entry.pomodoro :as pomo]
            [clojure.data :as data]
            [clojure.pprint :as pp]))

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

(defn draft-text-editor [ts update-cb save-fn start-fn small-img changed]
  (let [editor (adapt-react-class "EntryTextEditor")
        {:keys [entry entries-map]} (eu/entry-reaction ts)
        options (subscribe [:options])
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
    (fn draft-editor-render [ts update-cb save-fn start-fn small-img changed]
      (let [md (or (get-in @entry [:md]) "")]
        (debug :draft-editor-render ts)
        [editor {:md       md
                 :ts       ts
                 :changed  changed
                 :mentions @mentions
                 :hashtags @hashtags
                 :saveFn   save-fn
                 :startFn  start-fn
                 :smallImg small-img
                 :onChange update-cb}]))))

(defn entry-editor [ts put-fn]
  (let [{:keys [entry edit-mode unsaved new-entries entries-map]} (eu/entry-reaction ts)
        editor-cb (fn [md plain]
                    (when-not (= md (:md @entry))
                      (let [updated (merge
                                      @entry
                                      (p/parse-entry md)
                                      {:text plain})]
                        (when (:timestamp updated)
                          (put-fn [:entry/update-local updated])))))]
    (fn [ts put-fn]
      (let [latest-entry (dissoc @entry :comments)
            save-fn (fn [md plain]
                      (let [cleaned (u/clean-entry latest-entry)
                            updated (merge cleaned
                                           (p/parse-entry md)
                                           {:text plain})
                            updated (if (= (:entry-type latest-entry) :pomodoro)
                                      (assoc-in updated [:pomodoro-running] false)
                                      updated)]
                        (when (:pomodoro-running latest-entry)
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
                            (put-fn [:entry/update-local updated]))))]
        (when @unsaved
          #_(debug
              (time
                (let [[things-only-in-a things-only-in-b _things-in-both]
                      (data/diff (eu/compare-relevant (get-in @entries-map [ts]))
                                 (eu/compare-relevant (get-in @new-entries [ts])))]
                  (str "\n--- only in entry from entries-map:\n"
                       (with-out-str (pp/pprint things-only-in-a))
                       "\n--- only in entry from new-entries:\n"
                       (with-out-str (pp/pprint things-only-in-b)))))))
        ^{:key (:vclock @entry)}
        [:div {:class (when @unsaved "unsaved")}
         [draft-text-editor ts editor-cb save-fn start-fn small-img @unsaved]]))))
