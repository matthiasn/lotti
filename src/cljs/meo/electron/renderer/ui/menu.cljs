(ns meo.electron.renderer.ui.menu
  (:require [meo.electron.renderer.helpers :as h]
            [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [matthiasn.systems-toolbox.component :as stc]
            [reagent.core :as r]
            [react-dates :as rd]
            [cljs.reader :refer [read-string]]
            [meo.common.utils.parse :as up]
            [meo.common.utils.parse :as p]
            [matthiasn.systems-toolbox.component :as st]))

(defn toggle-option-view [{:keys [option cls]} put-fn]
  (let [cfg (subscribe [:cfg])]
    (fn toggle-option-render [{:keys [option cls]} put-fn]
      (let [show-option? (option @cfg)
            toggle-option #(put-fn [:cmd/toggle-key {:path [:cfg option]}])]
        [:span.fa.toggle
         {:class    (str cls (when-not show-option? " inactive"))
          :on-click toggle-option}]))))

(def limited-options
  [{:option :show-pvt :cls "fa-user-secret"}
   {:option :single-column :cls "fa-columns"}
   {:option :sort-asc :cls " fa-sort-asc"}
   {:option :app-screenshot :cls "fa-window-minimize"}])

(def all-options
  [{:option :show-pvt :cls "fa-user-secret"}
   {:option :comments-standalone :cls "fa-comments"}
   {:option :mute :cls "fa-volume-off"}
   {:option :ticking-clock :cls "fa-clock-o"}
   {:option :hide-hashtags :cls "fa-hashtag"}
   {:option :single-column :cls "fa-columns"}
   {:option :sort-asc :cls " fa-sort-asc"}
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
        screenshot #(put-fn [:screenshot/take])]
    (fn [put-fn]
      [:div
       (for [option (if @planning-mode all-options limited-options)]
         ^{:key (str "toggle" (:cls option))}
         [toggle-option-view option put-fn])
       [:span.fa.fa-desktop.toggle.inactive
        {:on-click screenshot}]
       [:span.fa.fa-qrcode.toggle
        {:on-click toggle-qr-code
         :class    (when-not (:qr-code @cfg) "inactive")}]])))

(defn upload-view []
  (let [cfg (subscribe [:cfg])
        iww-host (.-iwwHOST js/window)]
    (fn upload-view2-render []
      (when (:qr-code @cfg)
        [:img {:src (str "http://" iww-host "/upload-address/"
                         (stc/make-uuid) "/qrcode.png")}]))))

(defn calendar-view [put-fn]
  (let [calendar (r/adapt-react-class rd/SingleDatePicker)
        briefings (subscribe [:briefings])
        cfg (subscribe [:cfg])
        planning-mode (subscribe [:planning-mode])
        local (r/atom {:focused false})
        select-date (fn [dt]
                      (let [fmt (.format dt "YYYY-MM-DD")
                            q (up/parse-search (str "b:" fmt))]
                        (swap! local assoc-in [:date] dt)
                        (when-not (get @briefings fmt)
                          (let [weekday (.format dt "dddd")
                                md (str "## " weekday "'s #briefing")
                                new-entry (merge
                                            (p/parse-entry md)
                                            {:briefing      {:day fmt}
                                             :primary-story (-> @cfg :briefing :story)})
                                new-entry-fn (h/new-entry-fn put-fn new-entry nil)]
                            (new-entry-fn)))
                        (put-fn [:search/add {:tab-group :briefing :query q}])
                        (put-fn [:search/refresh])))
        focus-fn #(swap! local update-in [:focused] not)
        briefing-days (reaction (set (keys @briefings)))
        highlighted? (fn [day] (contains? @briefing-days (h/ymd day)))]
    (fn stats-view-render [put-fn]
      (when @planning-mode
        [:div.calendar
         [calendar {:placeholder        "briefing"
                    :date               (:date @local)
                    :on-date-change     select-date
                    :is-day-highlighted highlighted?
                    :focused            (:focused @local)
                    :on-focus-change    focus-fn
                    :is-outside-range   (constantly false)}]]))))

(defn busy-status []
  (let [busy-color (subscribe [:busy-color])
        planning-mode (subscribe [:planning-mode])]
    (fn busy-status-render []
      (when @planning-mode
        [:div.busy-status {:class (name (or @busy-color :green))}]))))

(defn menu-view [put-fn]
  [:div.menu
   [:div.menu-header
    [busy-status]
    [new-import-view put-fn]
    [calendar-view put-fn]
    [:h1 "meo"]
    [cfg-view put-fn]
    [upload-view]]])
