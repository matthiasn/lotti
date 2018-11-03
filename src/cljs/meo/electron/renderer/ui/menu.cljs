(ns meo.electron.renderer.ui.menu
  (:require [meo.electron.renderer.helpers :as h]
            [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [matthiasn.systems-toolbox.component :as stc]
            [reagent.core :as r]
            [taoensso.timbre :refer-macros [info]]
            [cljs.reader :refer [read-string]]
            [meo.common.utils.parse :as up]))

(defn toggle-option-view [{:keys [option cls]} put-fn]
  (let [cfg (subscribe [:cfg])]
    (fn toggle-option-render [{:keys [option cls]} put-fn]
      (let [show-option? (option @cfg)
            toggle-option #(do (put-fn [:cmd/toggle-key {:path [:cfg option]}])
                               (put-fn [:startup/query]))]
        [:i.far.toggle
         {:class    (str cls (when-not show-option? " inactive"))
          :on-click toggle-option}]))))

(defn change-language [cc]
  (let [spellcheck-handler (.-spellCheckHandler js/window)]
    (.switchLanguage spellcheck-handler cc)))

(defn new-import-view [put-fn]
  (let [local (r/atom {:show false})
        open-new (fn [x]
                   (put-fn [:search/add
                            {:tab-group :left
                             :query     (up/parse-search (:timestamp x))}]))]
    (def ^:export new-entry (h/new-entry put-fn {} open-new))
    (def ^:export new-story (h/new-entry put-fn {:entry_type :story} open-new))
    (def ^:export new-saga (h/new-entry put-fn {:entry_type :saga} open-new))
    (fn [put-fn]
      (when (:show @local)
        [:div.new-import
         [:button.menu-new {:on-click (h/new-entry put-fn {})}
          [:span.fa.fa-plus-square] " new"]
         [:button.menu-new
          {:on-click (h/new-entry put-fn {:entry_type :saga})}
          [:span.fa.fa-plus-square] " new saga"]
         [:button.menu-new
          {:on-click (h/new-entry put-fn {:entry_type :story})}
          [:span.fa.fa-plus-square] " new story"]
         [:button {:on-click #(do (put-fn [:import/photos])
                                  (put-fn [:import/spotify]))}
          [:span.fa.fa-map] " import"]]))))

(defn upload-view []
  (let [cfg (subscribe [:cfg])
        iww-host (.-iwwHOST js/window)]
    (fn upload-view-render []
      [:div
       (when (:qr-code @cfg)
         [:img {:src (str "http://" iww-host "/upload-address/"
                          (stc/make-uuid) "/qrcode.png")}])])))

(defn habit-monitor [put-fn]
  (let [gql-res (subscribe [:gql-res])
        habits (reaction (->> @gql-res
                              :habits-success
                              :data
                              :habits_success
                              (sort-by #(first (:completed %)))))]
    (fn upload-view-render []
      [:div.habit-monitor
       (for [habit @habits]
         (let [completed (first (:completed habit))
               cls (when completed "completed")
               text (-> habit :habit_entry :md)
               ts (-> habit :habit_entry :timestamp)
               on-click (up/add-search ts :right put-fn)]
           [:div.status.tooltip {:key      ts
                                 :class    cls
                                 :on-click on-click}
            (when-not completed
              [:div.progress
               {:style {:width (str (rand-int 100) "%")}}])
            [:span.tooltiptext (-> text)]]))])))

(defn busy-status [put-fn]
  (let [status (subscribe [:busy-status])
        click (fn [_]
                (let [q (up/parse-search (str (:active @status)))]
                  (put-fn [:search/add {:tab-group :left :query q}])))]
    (fn busy-status-render [_]
      (let [cls (name (or (:color @status) :green))]
        [:div.busy-status.rec-indicator {:class    cls
                                         :on-click click}]))))

(defn menu-view [put-fn]
  [:div.menu
   [:div.menu-header
    [habit-monitor put-fn]
    [new-import-view put-fn]
    [new-import-view put-fn]
    (when (.-PLAYGROUND js/window)
      [:h1.playground "Playground"])
    [upload-view]]])
