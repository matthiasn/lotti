(ns meins.electron.renderer.ui.menu
  (:require [meins.electron.renderer.helpers :as h]
            [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [reagent.core :as r]
            [taoensso.timbre :refer-macros [info debug]]
            [meins.common.habits.util :as hu]
            [cljs.reader :refer [read-string]]
            [meins.common.utils.parse :as up]
            [meins.common.utils.misc :as u]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [meins.common.utils.misc :as m]
            [meins.electron.renderer.ui.charts.award :as ca]))

(defn toggle-option-view [{:keys [option cls]}]
  (let [cfg (subscribe [:cfg])]
    (fn toggle-option-render [{:keys [option cls]}]
      (let [show-option? (option @cfg)
            toggle-option #(do (emit [:cmd/toggle-key {:path [:cfg option]}])
                               (emit [:startup/query]))]
        [:i.far.toggle
         {:class    (str cls (when-not show-option? " inactive"))
          :on-click toggle-option}]))))

(defn change-language [cc]
  (let [spellcheck-handler (.-spellCheckHandler js/window)]
    (.switchLanguage spellcheck-handler cc)))

(defn upload-view []
  (let [cfg (subscribe [:cfg])
        iww-host (.-iwwHOST js/window)]
    (fn upload-view-render []
      [:div
       (when (:qr-code @cfg)
         [:img {:src (str "http://" iww-host "/upload-address/"
                          (stc/make-uuid) "/qrcode.png")}])])))

(defn busy-status []
  (let [status (subscribe [:busy-status])
        click (fn [_]
                (let [q (up/parse-search (str (:active @status)))]
                  (emit [:search/add {:tab-group :left :query q}])))]
    (fn busy-status-render [_]
      (let [cls (name (or (:color @status) :green))]
        [:div.busy-status.rec-indicator {:class    cls
                                         :on-click click}]))))

(defn menu-view []
  [:div.menu
   [:div.menu-header
    [toggle-option-view {:cls    "fa-user-secret"
                         :option :show-pvt}]
    (when (.-PLAYGROUND js/window)
      [:h1.playground "Playground"])
    [upload-view]]])

(defn menu-view2 [title]
  [:div.menu
   [:div.menu-header
    [toggle-option-view {:cls    "fa-user-secret"
                         :option :show-pvt}]
    (when title
      [:h1 title])
    [:h1 title]
    (when (.-PLAYGROUND js/window)
      [:h1.playground "Playground"])
    [upload-view]]])
