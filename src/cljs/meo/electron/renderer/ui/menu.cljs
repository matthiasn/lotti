(ns meo.electron.renderer.ui.menu
  (:require [meo.electron.renderer.helpers :as h]
            [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [matthiasn.systems-toolbox.component :as stc]
            [reagent.core :as r]
            [taoensso.timbre :refer-macros [info]]
            [cljs.reader :refer [read-string]]
            [meo.common.utils.parse :as up]
            [matthiasn.systems-toolbox.component :as st]))

(defn toggle-option-view [{:keys [option cls]} put-fn]
  (let [cfg (subscribe [:cfg])]
    (fn toggle-option-render [{:keys [option cls]} put-fn]
      (let [show-option? (option @cfg)
            toggle-option #(put-fn [:cmd/toggle-key {:path [:cfg option]}])]
        [:i.far.toggle
         {:class    (str cls (when-not show-option? " inactive"))
          :on-click toggle-option}]))))

(def limited-options
  [{:option :show-pvt :cls "fa-user-secret"}
   {:option :single-column :cls "fa-columns"}
   {:option :sort-asc :cls " fa-sort-asc"}
   {:option :app-screenshot :cls "fa-window-minimize"}])

(def all-options
  [{:option :show-pvt :cls "fa-user-secret"}
   ;{:option :comments-standalone :cls "fa-comments"}
   ;{:option :mute :cls "fa-volume-off"}
   ;{:option :ticking-clock :cls "fa-clock-o"}
   ;{:option :show-calendar :cls "fa-calendar"}
   ;{:option :hide-hashtags :cls "fa-hashtag"}
   ;{:option :single-column :cls "fa-columns"}
   {:option :thumbnails :cls "fa-images"}
   {:option :dashboard-banner :cls "fa-chart-line"}
   ;{:option :sort-asc :cls " fa-sort-asc"}
   {:option :app-screenshot :cls "fa-window-minimize"}])

(defn change-language [cc]
  (let [spellcheck-handler (.-spellCheckHandler js/window)]
    (.switchLanguage spellcheck-handler cc)))

(defn new-import-view [put-fn]
  (let [local (r/atom {:show false})]
    (def ^:export new-entry (h/new-entry-fn put-fn {} nil))
    (def ^:export new-story (h/new-entry-fn put-fn {:entry-type :story} nil))
    (def ^:export new-saga (h/new-entry-fn put-fn {:entry-type :saga} nil))
    (def ^:export planning #(put-fn [:cmd/toggle-key {:path [:cfg :planning-mode]}]))
    (fn [put-fn]
      (when (:show @local)
        [:div.new-import
         [:button.menu-new {:on-click (h/new-entry-fn put-fn {} nil)}
          [:span.fa.fa-plus-square] " new"]
         [:button.menu-new
          {:on-click (h/new-entry-fn put-fn {:entry-type :saga} nil)}
          [:span.fa.fa-plus-square] " new saga"]
         [:button.menu-new
          {:on-click (h/new-entry-fn put-fn {:entry-type :story} nil)}
          [:span.fa.fa-plus-square] " new story"]
         [:button {:on-click #(do (put-fn [:import/photos])
                                  (put-fn [:import/spotify]))}
          [:span.fa.fa-map] " import"]]))))

(defn cfg-view [put-fn]
  (let [cfg (subscribe [:cfg])
        planning-mode (subscribe [:planning-mode])
        toggle-qr-code #(put-fn [:import/listen])
        ws-address (fn [_]
                     (put-fn [:cmd/toggle-key {:path [:cfg :ws-qr-code]}])
                     (if (:ws-qr-code @cfg)
                       (put-fn [:sync/stop-server])
                       (put-fn [:sync/start-server])))
        screenshot #(put-fn [:screenshot/take])]
    (fn [put-fn]
      [:div
       (for [option (if @planning-mode all-options limited-options)]
         ^{:key (str "toggle" (:cls option))}
         [toggle-option-view option put-fn])
       [:i.far.fa-desktop.toggle.inactive
        {:on-click screenshot}]
       [:i.far.fa-qrcode.toggle
        {:on-click toggle-qr-code
         :class    (when-not (:qr-code @cfg) "inactive")}]
       [:i.far.fa-qrcode.toggle
        {:on-click ws-address
         :class    (when-not (:ws-qr-code @cfg) "inactive")}]])))

(defn upload-view []
  (let [cfg (subscribe [:cfg])
        iww-host (.-iwwHOST js/window)]
    (fn upload-view-render []
      [:div
       (when (:qr-code @cfg)
         [:img {:src (str "http://" iww-host "/upload-address/"
                          (stc/make-uuid) "/qrcode.png")}])
       (when (:ws-qr-code @cfg)
         [:img {:src (str "http://" iww-host "/ws-address/"
                          (stc/make-uuid) "/qrcode.png")}])])))

(defn busy-status [put-fn]
  (let [status (subscribe [:busy-status])
        planning-mode (subscribe [:planning-mode])
        click (fn [_]
                (let [q (up/parse-search (str (:active @status)))]
                  (put-fn [:search/add {:tab-group :left :query q}])))]
    (fn busy-status-render [put-fn]
      (let [cls (name (or (:color @status) :green))]
        (when @planning-mode
          [:div.busy-status {:class cls
                             :on-click click}])))))

(defn menu-view [put-fn]
  (let [cal-day (subscribe [:cal-day])
        cfg (subscribe [:cfg])]
    (fn [put-fn]
      (let [locale (:locale @cfg :en)
            day (or @cal-day (h/ymd (st/now)))]
        [:div.menu
         [:div.menu-header
          [new-import-view put-fn]
          [:h1 (h/localize-date day locale)]
          [busy-status put-fn]
          [cfg-view put-fn]
          [upload-view]]]))))
