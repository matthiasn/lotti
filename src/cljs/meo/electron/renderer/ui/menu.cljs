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
            [meo.common.utils.misc :as u]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.common.utils.misc :as m]
            [meo.electron.renderer.ui.charts.award :as ca]))

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
    (def ^:export new-habit (h/new-entry put-fn {:entry_type :habit} open-new))
    (def ^:export new-dashboard
      (h/new-entry put-fn {:entry_type :dashboard-cfg
                           :perm_tags  #{"#dashboard-cfg"}} open-new))
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

(defn percent-achieved [habit]
  (let [completed (first (:completed habit))
        f (fn [[i criterion]]
            (info criterion)
            (let [min-val (:min-val criterion)
                  req-n (:req-n criterion)
                  min-time (:min-time criterion)
                  v (get-in completed [:values i :v])
                  min-v (if min-time
                          (* 60 min-time)
                          (or min-val req-n))]
              (when (pos? min-v)
                (min (* 100 (/ v min-v)) 100))))
        by-criteria (map f (u/idxd (get-in habit [:habit_entry :habit :criteria])))
        cnt (count by-criteria)]
    (when (pos? cnt)
      (/ (apply + by-criteria)
         cnt))))

(defn habit-monitor [put-fn]
  (let [gql-res (subscribe [:gql-res])
        habits (reaction (->> @gql-res
                              :habits-success
                              :data
                              :habits_success
                              (sort-by #(:success (first (:completed %))))))]
    (fn upload-view-render []
      [:div.habit-monitor
       (for [habit @habits]
         (let [completed (first (:completed habit))
               success (:success completed)
               cls (when success "completed")
               min-time (get-in habit [:habit_entry :habit :criteria 0 :min-time])
               v (get-in completed [:values 0 :v])
               text (eu/first-line (:habit_entry habit))
               text2 (if min-time
                       (h/s-to-hh-mm v)
                       v)
               percent-completed (percent-achieved habit)
               ts (-> habit :habit_entry :timestamp)
               on-click (up/add-search ts :right put-fn)
               started (and percent-completed (not success))]
           [:div.tooltip {:key ts}
            [:div.status {:class    cls
                          :on-click on-click}
             (when started
               [:div.progress
                {:style {:width (str percent-completed "%")}}])]
            [:div.tooltiptext
             [:h4 text]
             (when (and started (pos? percent-completed)) [:div "Progress: " text2])
             [:div.completion
              (for [[i c] (m/idxd (reverse (take 99 (:completed habit))))]
                [:span.status {:class (when (:success c) "success")
                               :key   i}])]]]))])))

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
    [toggle-option-view {:cls    "fa-user-secret"
                         :option :show-pvt} put-fn]
    [habit-monitor put-fn]
    [new-import-view put-fn]
    (when (.-PLAYGROUND js/window)
      [:h1.playground "Playground"])
    [upload-view]
    [ca/award-points put-fn]]])
