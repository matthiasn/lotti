(ns meo.electron.renderer.ui.entry.dashboard-cfg
  (:require [matthiasn.systems-toolbox.component :as st]
            [moment]
            [meo.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.common.utils.misc :as m]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.entry.utils :as eu]))


(defn input-row [entry label cfg path put-fn]
  (let [v (get-in entry path)
        t (:type cfg)
        v (if (and v (= :time t)) (h/m-to-hh-mm v) v)
        on-change (fn [ev]
                    (let [xf (if (= :number t) js/parseFloat identity)
                          v (xf (h/target-val ev))
                          v (if (= :time t)
                              (.asMinutes (.duration moment v))
                              v)
                          updated (assoc-in entry path v)]
                      (put-fn [:entry/update-local updated])))]
    [:div.row
     [:label label]
     [:input (merge {:on-change on-change
                     :class     "time"
                     :value     v}
                    cfg)]]))


(defn habit-success [_]
  (let [habits (subscribe [:habits])]
    (fn [{:keys [put-fn entry idx] :as habit}]
      (let [path [:dashboard_cfg :items idx :habit]]
        [:div
         [:h4 "Habit Success or Failure"]
         [:div.row
          [:label.wide "Habit:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      path
                      :put-fn    put-fn
                      :xf        js/parseInt
                      :options   (zipmap (keys @habits)
                                         (map #(eu/first-line (:habit_entry %))
                                              (vals @habits)))}]]]))))


(defn quest-details [_]
  (let [backend-cfg (subscribe [:backend-cfg])]
    (fn [{:keys [put-fn entry idx]}]
      (let [q-tags (-> @backend-cfg :questionnaires :mapping)
            tag-path [:dashboard_cfg :items idx :k]
            h-path [:dashboard_cfg :items idx :h]
            color-path [:dashboard_cfg :items idx :color]
            label-path [:dashboard_cfg :items idx :label]
            show-details (not (empty? (str (get-in entry tag-path))))]
        [:div
         [:h4 "Questionnaire"]
         [:div.row
          [:label.wide "Tag:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      tag-path
                      :put-fn    put-fn
                      :xf        keyword
                      :options   (zipmap (vals q-tags) (keys q-tags))}]]
         (when show-details
           (let [tag (get-in entry tag-path)
                 aggs (get-in @backend-cfg [:questionnaires :items tag :aggregations])
                 options (zipmap (keys aggs) (map :label (vals aggs)))]
             [:div.row
              [:label.wide "Score:"]
              [uc/select {:entry     entry
                          :on-change uc/select-update
                          :path      [:dashboard_cfg :items idx :score_k]
                          :xf        keyword
                          :put-fn    put-fn
                          :options   options}]]))
         (when show-details
           [input-row entry "Row Height:" {:type :number} h-path put-fn])
         (when show-details
           [input-row entry "Label:" {} label-path put-fn])
         (when show-details
           [:div.row
            [:label.wide "Color:"]
            [uc/select {:entry     entry
                        :on-change uc/select-update
                        :path      color-path
                        :put-fn    put-fn
                        :options   {:red     "Red"
                                    :green   "Green"
                                    :blue    "Blue"
                                    :yellow  "Yellow"
                                    :magenta "Magenta"
                                    :cyan    "Cyan"
                                    :gray    "Gray"
                                    :black   "Black"}}]])]))))

(defn barchart-row [_]
  (let [backend-cfg (subscribe [:backend-cfg])]
    (fn [{:keys [put-fn entry idx]}]
      (let [custom-fields (get-in @backend-cfg [:custom-fields])
            tag-path [:dashboard_cfg :items idx :tag]
            h-path [:dashboard_cfg :items idx :h]
            mn-path [:dashboard_cfg :items idx :mn]
            mx-path [:dashboard_cfg :items idx :mx]
            tag-selected (not (empty? (str (get-in entry tag-path))))
            field-path [:dashboard_cfg :items idx :field]
            color-path [:dashboard_cfg :items idx :color]
            tag (get-in entry tag-path)
            field (get-in entry field-path)
            fields (get-in @backend-cfg [:custom-fields tag :fields])
            field-cfg (get-in fields [field :cfg])]
        [:div
         [:h4 "Custom Field"]
         [:div.row
          [:label.wide "Tag:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      tag-path
                      :put-fn    put-fn
                      :options   (keys custom-fields)}]]
         (when tag-selected
           (let [fields (get-in @backend-cfg [:custom-fields tag :fields])
                 options (zipmap (keys fields) (map :label (vals fields)))]
             [:div.row
              [:label.wide "Field:"]
              [uc/select {:entry     entry
                          :on-change uc/select-update
                          :path      field-path
                          :xf        keyword
                          :put-fn    put-fn
                          :options   options}]]))
         (when field
           [:div.row
            [:label.wide "Color:"]
            [uc/select {:entry     entry
                        :on-change uc/select-update
                        :path      color-path
                        :put-fn    put-fn
                        :options   {:red     "Red"
                                    :green   "Green"
                                    :blue    "Blue"
                                    :yellow  "Yellow"
                                    :magenta "Magenta"
                                    :cyan    "Cyan"
                                    :gray    "Gray"
                                    :black   "Black"}}]])
         (when field
           [input-row entry "Min:" field-cfg mn-path put-fn])
         (when field
           [input-row entry "Max:" field-cfg mx-path put-fn])
         (when field
           [input-row entry "Row Height:" {:type :number} h-path put-fn])]))))


(defn item [{:keys [entry idx put-fn] :as params}]
  (let [path [:dashboard_cfg :items idx :type]
        habit-type (get-in entry path)
        rm-click (fn []
                   (let [rm #(let [criteria %]
                               (vec (concat (take idx criteria)
                                            (drop (inc idx) criteria))))
                         updated (update-in entry [:dashboard_cfg :items] rm)]
                     (put-fn [:entry/update-local updated])))]
    [:div.criterion
     [:i.fas.fa-trash-alt {:on-click rm-click}]
     (when-not habit-type
       [:div.row
        [:label "Chart Type:"]
        [uc/select {:on-change uc/select-update
                    :entry     entry
                    :put-fn    put-fn
                    :path      path
                    :xf        keyword
                    :options   {:barchart_row  "Custom Field"
                                :habit_success "Habit Success"
                                :questionnaire "Questionnaire"}}]])
     (when (= :habit_success habit-type)
       [habit-success params])
     (when (= :barchart_row habit-type)
       [barchart-row params])
     (when (= :questionnaire habit-type)
       [quest-details params])]))


(defn dashboard-config [entry put-fn]
  (let [add-item (fn [entry]
                   (fn [_]
                     (let [updated (update-in entry [:dashboard_cfg :items] #(vec (conj % {})))]
                       (put-fn [:entry/update-local updated]))))]
    (fn [entry put-fn]
      (let [items (get-in entry [:dashboard_cfg :items])
            set-active #(put-fn [:dashboard/set items])]
        [:div.habit-details
         [:h3.header
          {:on-click set-active}
          "Dashboard Configuration"]
         [:div.row
          [:label "Active? "]
          [uc/switch {:entry entry :put-fn put-fn :path [:dashboard_cfg :active]}]]
         [:div.row
          [:h3 "Criteria"]
          [:div.add-criterion {:on-click (add-item entry)}
           [:i.fas.fa-plus]]]
         (for [[i c] (map-indexed (fn [i v] [i v]) items)]
           ^{:key i}
           [item {:entry  entry
                  :put-fn put-fn
                  :idx    i}])]))))
