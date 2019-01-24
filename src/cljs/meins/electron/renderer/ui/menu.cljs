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

(defn new-import-view []
  (let [local (r/atom {:show false})
        open-new (fn [x]
                   (emit [:search/add
                          {:tab-group :left
                           :query     (up/parse-search (:timestamp x))}]))]
    (fn []
      (when (:show @local)
        [:div.new-import
         [:button.menu-new {:on-click (h/new-entry {})}
          [:span.fa.fa-plus-square] " new"]
         [:button.menu-new
          {:on-click (h/new-entry {:entry_type :saga})}
          [:span.fa.fa-plus-square] " new saga"]
         [:button.menu-new
          {:on-click (h/new-entry {:entry_type :story})}
          [:span.fa.fa-plus-square] " new story"]
         [:button {:on-click #(do (emit [:import/photos])
                                  (emit [:import/spotify]))}
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
            (debug criterion)
            (let [min-val (:min-val criterion)
                  req-n (:req-n criterion)
                  min-time (:min-time criterion)
                  v (get-in completed [:values i :v])
                  min-v (if min-time
                          (* 60 min-time)
                          (or min-val req-n))]
              (when (pos? min-v)
                (min (* 100 (/ v min-v)) 100))))
        criteria (hu/get-criteria (:habit_entry habit) (h/ymd (stc/now)))
        by-criteria (map f (u/idxd criteria))
        cnt (count by-criteria)]
    (when (pos? cnt)
      (/ (apply + by-criteria)
         cnt))))

(defn habit-monitor []
  (let [gql-res (subscribe [:gql-res])
        pvt (subscribe [:show-pvt])
        habits (reaction (->> @gql-res
                              :habits-success
                              :data
                              :habits_success
                              (sort-by #(:success (first (:completed %))))))]
    (fn habit-monitor-render []
      (let [pvt @pvt
            habits (filter #(or pvt (not (get-in % [:habit_entry :habit :pvt]))) @habits)]
        [:div.habit-monitor
         (for [habit habits]
           (let [completed (first (:completed habit))
                 success (:success completed)
                 cls (when success "completed")
                 criteria (hu/get-criteria (:habit_entry habit) (h/ymd (stc/now)))
                 min-time (-> criteria first :min-time)
                 v (get-in completed [:values 0 :v])
                 text (eu/first-line (:habit_entry habit))
                 text2 (if min-time (h/s-to-hh-mm v) v)
                 percent-completed (percent-achieved habit)
                 ts (-> habit :habit_entry :timestamp)
                 on-click (up/add-search
                            {:tab-group    :right
                             :story-name   (-> habit :habit_entry :story :story_name)
                             :first-line   text
                             :query-string ts} emit)
                 started (and percent-completed (not success))]
             ^{:key ts}
             [:div.tooltip
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
                                 :key   i}])]]]))]))))

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
    [habit-monitor]
    [new-import-view]
    (when (.-PLAYGROUND js/window)
      [:h1.playground "Playground"])
    [upload-view]]])
