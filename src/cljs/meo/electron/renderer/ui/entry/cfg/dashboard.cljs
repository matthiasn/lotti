(ns meo.electron.renderer.ui.entry.cfg.dashboard
  (:require [react-color :as react-color]
            [meo.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.common.utils.misc :as m]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.electron.renderer.ui.entry.cfg.shared :as cs]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [reagent.core :as r]
            [moment]
            [meo.common.utils.parse :as up]))

(def chrome-picker (r/adapt-react-class react-color/ChromePicker))

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

(defn bp-chart [_]
  (let []
    (fn [{:keys [put-fn entry idx]}]
      (let [h-path [:dashboard_cfg :items idx :h]
            mn-path [:dashboard_cfg :items idx :mn]
            mx-path [:dashboard_cfg :items idx :mx]
            sw-path [:dashboard_cfg :items idx :stroke_width]
            csw-path [:dashboard_cfg :items idx :circle_stroke_width]
            cr-path [:dashboard_cfg :items idx :circle_radius]
            glow-path [:dashboard_cfg :items idx :glow]]
        [:div
         [:h4 "Blood pressure chart"]
         [cs/input-row entry {:type  :number
                              :label "Heigth:"
                              :path  h-path} put-fn]
         [cs/input-row entry {:label "Min:"
                              :type  :number
                              :path  mn-path} put-fn]
         [cs/input-row entry {:type  :number
                              :label "Max:"
                              :path  mx-path} put-fn]
         [cs/input-row entry {:type  :number
                              :label "Stroke:"
                              :path  sw-path} put-fn]
         [cs/input-row entry {:type  :number
                              :label "Circle Radius:"
                              :path  cr-path} put-fn]
         [cs/input-row entry {:type  :number
                              :label "Circle Stroke:"
                              :path  csw-path} put-fn]
         [:div.row
          [:label "Glow? "]
          [uc/switch {:entry entry :put-fn put-fn :path glow-path}]]]))))

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
            tag-path [:dashboard_cfg :items idx :tag]
            k-path [:dashboard_cfg :items idx :k]
            h-path [:dashboard_cfg :items idx :h]
            label-path [:dashboard_cfg :items idx :label]
            sw-path [:dashboard_cfg :items idx :stroke_width]
            mn-path [:dashboard_cfg :items idx :mn]
            mx-path [:dashboard_cfg :items idx :mx]
            glow-path [:dashboard_cfg :items idx :glow]
            csw-path [:dashboard_cfg :items idx :circle_stroke_width]
            cr-path [:dashboard_cfg :items idx :circle_radius]
            show-details (not (empty? (str (get-in entry k-path))))
            select-q (fn [{:keys [entry xf put-fn options]}]
                       (let [xf (or xf identity)]
                         (fn [ev]
                           (let [tv (h/target-val ev)
                                 sel (if (empty? tv) tv (xf tv))
                                 updated (assoc-in entry k-path sel)
                                 updated (assoc-in updated tag-path (get options sel))]
                             (put-fn [:entry/update-local updated])))))]
        [:div
         [:h4 "Questionnaire"]
         [:div.row
          [:label.wide "Tag:"]
          [uc/select {:entry     entry
                      :on-change select-q
                      :path      k-path
                      :put-fn    put-fn
                      :xf        keyword
                      :options   (zipmap (vals q-tags) (keys q-tags))}]]
         (when show-details
           (let [tag (get-in entry k-path)
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
           [cs/input-row entry {:type  :number
                                :label "Height:"
                                :path  h-path} put-fn])
         (when show-details
           [cs/input-row entry {:label "Label:"
                                :path  label-path} put-fn])
         (when show-details
           [cs/input-row entry {:label "Min:"
                                :type  :number
                                :path  mn-path} put-fn])
         (when show-details
           [cs/input-row entry {:label "Max:"
                                :type  :number
                                :path  mx-path} put-fn])
         (when show-details
           [cs/input-row entry {:label "Stroke:"
                                :type  :number
                                :path  sw-path} put-fn])
         (when show-details
           [cs/input-row entry {:label "Circle Radius:"
                                :type  :number
                                :path  cr-path} put-fn])
         (when show-details
           [cs/input-row entry {:label "Circle Stroke:"
                                :type  :number
                                :path  csw-path} put-fn])
         (when show-details
           [:div.row
            [:label "Glow? "]
            [uc/switch {:entry entry :put-fn put-fn :path glow-path}]])
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
           [cs/input-row entry (merge field-cfg
                                      {:label "Min:"
                                       :path  mn-path}) put-fn])
         (when field
           [cs/input-row entry (merge field-cfg
                                      {:label "Max:"
                                       :path  mx-path}) put-fn])
         (when field
           [cs/input-row entry {:label "Height:"
                                :type  :number
                                :path  h-path} put-fn])]))))


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
        mv-click (fn [f _]
                   (let [items (get-in entry items-path)
                         item (get-in entry [:dashboard_cfg :items idx])
                         items (vec (concat (take idx items) (drop (inc idx) items)))
                         items (vec (concat (take (f idx) items)
                                            [item]
                                            (drop (f idx) items)))
                         updated (assoc-in entry items-path items)]
                     (put-fn [:entry/update-local updated])))]
    [:div.criterion
     [:i.fas.fa-trash-alt.fr {:on-click rm-click}]
     (when (and (< idx (dec n)) (> n 1))
       [:i.fas.fa-arrow-down {:on-click (partial mv-click inc)}])
     (when (pos? idx)
       [:i.fas.fa-arrow-up {:on-click (partial mv-click dec)}])

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
                                :questionnaire "Questionnaire"
                                :bp_chart      "Blood Pressure"}}]])
     (when (= :habit_success habit-type)
       [habit-success params])
     (when (= :bp_chart habit-type)
       [bp-chart params])
     (when (= :barchart_row habit-type)
       [barchart-row params])
     (when (= :questionnaire habit-type)
       [quest-details params])]))


(defn dashboard-config [entry put-fn]
  (let [add-item (fn [entry]
                   (fn [_]
                     (let [updated (update-in entry [:dashboard_cfg :items] #(vec (conj % {})))]
                       (put-fn [:entry/update-local updated]))))
        open-new (fn [x]
                   (put-fn [:search/add
                            {:tab-group :left
                             :query     (up/parse-search (:timestamp x))}]))]
    (fn [entry put-fn]
      (let [items (get-in entry [:dashboard_cfg :items])
            copy-opts {:dashboard_cfg (:dashboard_cfg entry)
                       :entry_type    :dashboard-cfg
                       :perm_tags     #{"#dashboard-cfg"}}
            copy-click (h/new-entry put-fn copy-opts open-new)]
        [:div.habit-details
         [:h3.header
          "Dashboard Configuration"]
         [:div.row
          [:label "Active? "]
          [uc/switch {:entry entry :put-fn put-fn :path [:dashboard_cfg :active]}]]
         [:div.row
          [:label "Private? "]
          [uc/switch {:entry entry :put-fn put-fn :path [:dashboard_cfg :pvt]}]]
         [:div.row
          [:h3 "Criteria"]
          [:div.add-criterion {:on-click (add-item entry)}
           [:i.fas.fa-plus]]
          [:div.spacer]
          [:div.copy-dashboard
           {:on-click copy-click}
           [:i.fas.fa-copy]
           "copy"]]
         (for [[i c] (map-indexed (fn [i v] [i v]) items)]
           ^{:key i}
           [item {:entry  entry
                  :put-fn put-fn
                  :idx    i}])]))))
