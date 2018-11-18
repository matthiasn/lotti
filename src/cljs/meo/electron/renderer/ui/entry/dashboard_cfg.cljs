(ns meo.electron.renderer.ui.entry.dashboard-cfg
  (:require [react-color :as react-color]
            [meo.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.common.utils.misc :as m]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [reagent.core :as r]
            [moment]))

(def chrome-picker (r/adapt-react-class react-color/ChromePicker))

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

(defn color-picker [entry idx put-fn]
  (let [color-path [:dashboard_cfg :items idx :color]
        set-color (fn [data]
                    (let [hex (aget data "hex")
                          updated (assoc-in entry color-path hex)]
                      (put-fn [:entry/update-local updated])))]
    [:div.row
     [:label.wide "Color:"]
     [chrome-picker {:disableAlpha     true
                     :color            (get-in entry color-path "#ccc")
                     :onChangeComplete set-color}]]))

(defn quest-details [_]
  (let [backend-cfg (subscribe [:backend-cfg])]
    (fn [{:keys [put-fn entry idx]}]
      (let [q-tags (-> @backend-cfg :questionnaires :mapping)
            tag-path [:dashboard_cfg :items idx :k]
            h-path [:dashboard_cfg :items idx :h]
            label-path [:dashboard_cfg :items idx :label]
            sw-path [:dashboard_cfg :items idx :stroke_width]
            mn-path [:dashboard_cfg :items idx :mn]
            mx-path [:dashboard_cfg :items idx :mx]
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
           [input-row entry "Height:" {:type :number} h-path put-fn])
         (when show-details
           [input-row entry "Label:" {} label-path put-fn])
         (when show-details
           [input-row entry "Min:" {:type :number} mn-path put-fn])
         (when show-details
           [input-row entry "Max:" {:type :number} mx-path put-fn])
         (when show-details
           [input-row entry "Stroke:" {:type :number} sw-path put-fn])
         (when show-details
           [color-picker entry idx put-fn])]))))

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
           [color-picker entry idx put-fn])
         (when field
           [input-row entry "Min:" field-cfg mn-path put-fn])
         (when field
           [input-row entry "Max:" field-cfg mx-path put-fn])
         (when field
           [input-row entry "Height:" {:type :number} h-path put-fn])]))))


(defn item [{:keys [entry idx put-fn] :as params}]
  (let [path [:dashboard_cfg :items idx :type]
        habit-type (get-in entry path)
        items-path [:dashboard_cfg :items]
        n (count (get-in entry items-path))
        rm-click (fn []
                   (let [items (get-in entry items-path)
                         items (vec (concat (take idx items) (drop (inc idx) items)))
                         updated (assoc-in entry items-path items)]
                     (put-fn [:entry/update-local updated])))
        up-click (fn []
                   (let [items (get-in entry items-path)
                         item (get-in entry [:dashboard_cfg :items idx])
                         items (vec (concat (take idx items) (drop (inc idx) items)))
                         items (vec (concat (take (dec idx) items)
                                            [item]
                                            (drop (dec idx) items)))
                         updated (assoc-in entry items-path items)]
                     (put-fn [:entry/update-local updated])))
        down-click (fn []
                     (let [items (get-in entry items-path)
                           item (get-in entry [:dashboard_cfg :items idx])
                           items (vec (concat (take idx items) (drop (inc idx) items)))
                           items (vec (concat (take (inc idx) items)
                                              [item]
                                              (drop (inc idx) items)))
                           updated (assoc-in entry items-path items)]
                       (put-fn [:entry/update-local updated])))]
    [:div.criterion
     [:i.fas.fa-trash-alt.fr {:on-click rm-click}]
     (when (and (< idx (dec n)) (> n 1))
       [:i.fas.fa-arrow-down {:on-click down-click}])
     (when (pos? idx)
       [:i.fas.fa-arrow-up {:on-click up-click}])

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
            set-active #(put-fn [:dashboard/set entry])]
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
