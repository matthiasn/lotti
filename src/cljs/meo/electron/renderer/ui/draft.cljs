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
            [matthiasn.systems-toolbox.component :as st]
            [clojure.set :as set]
            [cljs.pprint :as pp]))

(defn editor-state-from-text [text]
  (let [content-from-text (.createFromText Draft.ContentState text)]
    (.createWithContent Draft.EditorState content-from-text)))

(defn editor-state-from-raw [editor-state]
  (let [content-from-raw (.convertFromRaw Draft editor-state)]
    (.createWithContent Draft.EditorState content-from-raw)))

(defn story-mapper [story]
  (when-let [story-name (:story-name story)]
    {:name story-name
     :id   (:timestamp story)}))

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
        cfg (subscribe [:cfg])
        gql-res (subscribe [:gql-res])
        mentions (reaction (map (fn [m] {:name m})
                                (-> @gql-res :options :data :mentions)))
        stories (reaction (filter identity
                                  (map story-mapper
                                       (-> @gql-res :options :data :stories))))
        hashtags (reaction
                   (let [show-pvt? (:show-pvt @cfg)
                         hashtags (-> @gql-res :options :data :hashtags)
                         pvt-hashtags (-> @gql-res :options :data :pvt_hashtags)
                         hashtags (if show-pvt?
                                    (concat hashtags pvt-hashtags)
                                    hashtags)]
                     (map (fn [h] {:name h}) hashtags)))
        on-change (on-editor-change update-cb)]
    (fn [editor-state _send-fn]
      [editor {:editorState editor-state
               :mentions    @mentions
               :hashtags    @hashtags
               :stories     @stories
               :onChange    on-change}])))

(defn draft-text-editor [entry2 update-cb save-fn start-fn small-img]
  (let [ts (:timestamp entry2)
        editor (adapt-react-class "EntryTextEditor")
        {:keys [new-entry unsaved]} (eu/entry-reaction ts)
        cfg (subscribe [:cfg])
        gql-res (subscribe [:gql-res])
        mentions (reaction (map (fn [m] {:name m})
                                (get-in @gql-res [:options :data :mentions])))
        hashtags (reaction
                   (let [show-pvt? (:show-pvt @cfg)
                         hashtags (-> @gql-res :options :data :hashtags)
                         pvt-hashtags (-> @gql-res :options :data :pvt_hashtags)
                         hashtags (if show-pvt?
                                    (concat hashtags pvt-hashtags)
                                    hashtags)]
                     (map (fn [h] {:name h}) hashtags)))]
    (fn draft-editor-render [entry2 update-cb save-fn start-fn small-img]
      [editor {:md       (or (:md @new-entry) (:md entry2))
               :ts       ts
               :changed  @unsaved
               :mentions @mentions
               :hashtags @hashtags
               :saveFn   save-fn
               :startFn  start-fn
               :smallImg small-img
               :onChange update-cb}])))

(defn entry-editor [entry2 put-fn]
  (let [ts (:timestamp entry2)
        {:keys [entry new-entry unsaved]} (eu/entry-reaction ts)
        cb-atom (atom {:last-sent 0})
        update-local (fn []
                       (let [start (st/now)
                             editor-state (:editor-state @cb-atom)
                             content (.getCurrentContent editor-state)
                             plain (.getPlainText content)
                             raw-content (.convertToRaw Draft content)
                             md (.draftjsToMd md-converter raw-content md-dict)
                             updated (merge entry2
                                            (p/parse-entry md)
                                            {:text         plain
                                             :edit-running true})]
                         (swap! cb-atom dissoc :timeout)
                         (when (not= md (:md @entry))
                           (when (:timestamp updated)
                             (put-fn [:entry/update-local updated]))
                           (debug "update-local" (:timestamp updated)
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
                        updated (update-in updated [:tags] set/union (:perm-tags updated))
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
    (fn [entry2 _put-fn]
      (let [unsaved (or (when @new-entry (not= (:md entry2) (:md @new-entry)))
                        @unsaved)]
        ^{:key (str (:vclock entry2))}
        [:div {:class (when unsaved "unsaved")}
         [draft-text-editor entry2 change-cb save-fn start-fn small-img]]))))
