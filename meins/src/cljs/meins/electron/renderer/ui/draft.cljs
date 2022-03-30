(ns meins.electron.renderer.ui.draft
  (:require ["@matthiasn/draftjs-md-converter" :as md-converter]
            [clojure.set :as set]
            [clojure.string :as s]
            [clojure.walk :as walk]
            ["draft-js" :as Draft]
            [matthiasn.systems-toolbox.component :as st]
            [meins-draft]
            [meins.common.utils.misc :as u]
            [meins.common.utils.parse :as p]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug info]]))

(defn editor-state-from-text [text]
  (let [content-from-text (.createFromText Draft/ContentState text)]
    (.createWithContent Draft/EditorState content-from-text)))

(defn editor-state-from-raw [editor-state]
  (let [content-from-raw (.convertFromRaw Draft editor-state)]
    (.createWithContent Draft/EditorState content-from-raw)))

(defn story-mapper [story]
  (when-let [story-name (:story_name story)]
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
  (let [editor (r/adapt-react-class meins-draft/SearchFieldEditor)
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

(defn remove-nils [m]
  (let [f (fn [[k v]] (when v [k v]))]
    (walk/postwalk (fn [x] (if (map? x) (into {} (map f x)) x)) m)))

(defn nilable-replace [s match replacement]
  (when (string? s) (s/replace s match replacement)))

(defn compare-entries [x y]
  (let [x (remove-nils x)
        y (remove-nils y)
        y (assoc y :tags (set/union (:perm_tags y) (:tags y)))
        ks (set/intersection (set (keys x))
                             (set (keys y)))
        ks (conj ks :starred :flagged :latitude :longitude :habit :custom_field_cfg :story_cfg :saga_cfg :post_mortem :problem_review)
        x1 (u/clean-entry (select-keys x ks))
        y1 (u/clean-entry (select-keys y ks))
        x2 (update-in x1 [:md] nilable-replace " " "")
        y2 (update-in y1 [:md] nilable-replace " " "")
        eq (= x2 y2)
        diff (clojure.data/diff x2 y2)]
    (when-not eq
      (debug (first diff))
      (debug (second diff)))
    (not eq)))

(def editor (r/adapt-react-class meins-draft/EntryTextEditor))

(defn editor-wrapper [_]
  (fn [props]
    [editor props]))

(defn entry-editor [entry2 errors]
  (let [ts (:timestamp entry2)
        {:keys [new-entry]} (eu/entry-reaction ts)
        cb-atom (atom {:last-sent 0})
        status (subscribe [:busy-status])
        mentions (subscribe [:mentions])
        hashtags (subscribe [:hashtags])
        update-local (fn []
                       (let [start (st/now)
                             editor-state (:editor-state @cb-atom)
                             content (.getCurrentContent editor-state)
                             plain (.getPlainText content)
                             raw-content (.convertToRaw Draft content)
                             md (.draftjsToMd md-converter raw-content md-dict)
                             x (merge @new-entry
                                      (p/parse-entry md)
                                      {:text         plain
                                       :timestamp    (:timestamp entry2)
                                       :edit-running true})
                             x (update-in x [:tags] set/union (:perm_tags entry2))]
                         (swap! cb-atom dissoc :timeout)
                         (when (and (not= md (:md entry2))
                                    (or (not @new-entry)
                                        (not= md (:md @new-entry))))
                           (emit [:entry/update-local x])
                           (debug "update-local" (:timestamp x) md
                                  "-" (- (st/now) start) "ms"))))
        change-cb (fn [editor-state]
                    (swap! cb-atom assoc-in [:editor-state] editor-state)
                    (when-not (:timeout @cb-atom)
                      (let [timeout (js/setTimeout update-local 500)]
                        (swap! cb-atom assoc-in [:timeout] timeout))))
        save-fn (fn [md plain]
                  (let [cleaned (u/clean-entry entry2)
                        updated (merge (dissoc cleaned :edit-running)
                                       @new-entry
                                       (p/parse-entry md)
                                       {:text plain})
                        updated (update-in updated [:tags] set/union (:perm_tags updated))
                        updated (if (= (:entry_type cleaned) :pomodoro)
                                  (assoc-in updated [:pomodoro-running] false)
                                  updated)]
                    (when-let [timeout (:timeout @cb-atom)]
                      (js/clearTimeout timeout)
                      (swap! cb-atom dissoc :timeout))
                    (when (and (= (:comment_for cleaned) (:active @status))
                               (= ts (:current @status)))
                      (emit [:window/progress {:v 0}])
                      (emit [:blink/busy {:color :green}])
                      (emit [:cmd/pomodoro-stop updated]))
                    (when (empty? errors)
                      (emit [:entry/update-local updated])
                      (emit [:entry/update updated]))))
        start-fn #(let [latest-entry (merge (dissoc entry2 :comments)
                                            @new-entry)]
                    (when (= (:entry_type latest-entry) :pomodoro)
                      (emit [:cmd/pomodoro-start latest-entry])))]
    (fn [entry2 errors]
      (let [unsaved (when (and @new-entry (empty? errors))
                      (compare-entries entry2 @new-entry))
            err (seq errors)]
        [:div {:class (str (when unsaved "unsaved ")
                           (when err "validation-error"))}
         [editor-wrapper
          {:md       (or (:md @new-entry) (:md entry2) "")
           :ts       ts
           :changed  unsaved
           :mentions (distinct @mentions)
           :hashtags (distinct @hashtags)
           :saveFn   save-fn
           :startFn  start-fn
           :onChange change-cb}]]))))
