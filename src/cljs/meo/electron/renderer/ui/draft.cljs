(ns meo.electron.renderer.ui.draft
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]
            [taoensso.timbre :refer-macros [info debug]]
            [meo.common.utils.parse :as p]
            [meo.common.utils.misc :as u]
            [draft-js :as Draft]
            [draftjs-md-converter :as md-converter]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.electron.renderer.ui.entry.pomodoro :as pomo]
            [clojure.data :as data]
            [clojure.pprint :as pp]
            [matthiasn.systems-toolbox.component :as st]))

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

(def md-dict (clj->js {:BOLD          "**"
                       :STRIKETHROUGH "~~"
                       :CODE          "`"
                       :UNDERLINE     "__"}))

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

(defn draft-text-editor [ts update-cb save-fn start-fn small-img]
  (let [editor (adapt-react-class "EntryTextEditor")
        {:keys [entry unsaved]} (eu/entry-reaction ts)
        md (reaction (:md @entry ""))
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
    (fn draft-editor-render [ts update-cb save-fn start-fn small-img]
      (debug :draft-editor-render ts)
      [editor {:md       @md
               :ts       ts
               :changed  @unsaved
               :mentions @mentions
               :hashtags @hashtags
               :saveFn   save-fn
               :startFn  start-fn
               :smallImg small-img
               :onChange update-cb}])))

(defn entry-editor [ts put-fn]
  (let [{:keys [entry unsaved]} (eu/entry-reaction ts)
        vclock (reaction (:vclock @entry))
        cb-atom (atom {:last-sent 0})
        update-local (fn []
                       (let [start (st/now)
                             editor-state (:editor-state @cb-atom)
                             content (.getCurrentContent editor-state)
                             plain (.getPlainText content)
                             raw-content (.convertToRaw Draft content)
                             md (.draftjsToMd md-converter raw-content md-dict)
                             updated (merge @entry
                                            (p/parse-entry md)
                                            {:text         plain
                                             :edit-running true})]
                         (swap! cb-atom dissoc :timeout)
                         (when (not= md (:md @entry))
                           (when (:timestamp updated)
                             (put-fn [:entry/update-local updated]))
                           (info "update-local" (:timestamp updated)
                                 "-" (- (st/now) start) "ms"))))
        change-cb (fn [editor-state]
                    (swap! cb-atom assoc-in [:editor-state] editor-state)
                    (when-not (:timeout @cb-atom)
                      (let [timeout (.setTimeout js/window update-local 1000)]
                        (swap! cb-atom assoc-in [:timeout] timeout))))
        save-fn (fn [md plain]
                  (let [latest-entry (dissoc @entry :comments)
                        cleaned (u/clean-entry latest-entry)
                        updated (merge (dissoc cleaned :edit-running)
                                       (p/parse-entry md)
                                       {:text plain})
                        updated (if (= (:entry-type latest-entry) :pomodoro)
                                  (assoc-in updated [:pomodoro-running] false)
                                  updated)]
                    (when-let [timeout (:timeout @cb-atom)]
                      (.clearTimeout js/window timeout)
                      (swap! cb-atom dissoc :timeout))
                    (when (:pomodoro-running latest-entry)
                      (put-fn [:window/progress {:v 0}])
                      (put-fn [:blink/busy {:color :green}])
                      (put-fn [:cmd/pomodoro-stop updated]))
                    (put-fn [:entry/update-local updated])
                    (put-fn [:entry/update updated])))
        start-fn #(let [latest-entry (dissoc @entry :comments)]
                    (when (= (:entry-type latest-entry) :pomodoro)
                      (put-fn [:cmd/pomodoro-start latest-entry])))
        small-img (fn [smaller]
                    (let [img-size (:img-size @entry 50)
                          img-size (if smaller (- img-size 10) (+ img-size 10))
                          updated (assoc-in @entry [:img-size] img-size)]
                      (when (and (pos? img-size)
                                 (< img-size 101)
                                 (:timestamp updated))
                        (put-fn [:entry/update-local updated]))))]
    (fn [_ts _put-fn]
      (debug :entry-editor-render ts)
      ^{:key @vclock}
      [:div {:class (when @unsaved "unsaved")}
       [draft-text-editor ts change-cb save-fn start-fn small-img]])))
