(ns meo.electron.renderer.ui.entry.cfg.custom-field
  (:require [react-color :as react-color]
            [meo.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.ui.entry.cfg.shared :as cs]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.electron.renderer.helpers :as h]
            [moment]
            [meo.common.utils.parse :as p]))

(defn is-tag? [s] (when (string? s) (re-find (re-pattern (str "^#" p/tag-char-cls "+$")) s)))

(defn valid-name? [s]
  (let [s (if (keyword? s) (name s) s)]
    (when (string? s) (re-find (re-pattern (str "^" p/tag-char-cls "+$")) s))))

(defn field-row [_]
  (let [backend-cfg (subscribe [:backend-cfg])]
    (fn [{:keys [put-fn entry idx]}]
      (let [tag-path [:custom_field_cfg :items idx :tag]
            agg-path [:custom_field_cfg :items idx :agg]
            step-path [:custom_field_cfg :items idx :step]
            field-path [:custom_field_cfg :items idx :field]
            name-path [:custom_field_cfg :items idx :name]
            label-path [:custom_field_cfg :items idx :label]
            type-path [:custom_field_cfg :items idx :type]
            tag (get-in entry tag-path)
            field (get-in entry field-path)
            fields (get-in @backend-cfg [:custom-fields tag :fields])
            field-cfg (get-in fields [field :cfg])
            t (get-in entry type-path)]
        [:div
         [:h4 "Custom Field"]
         [cs/input-row entry (merge field-cfg
                                    {:label    "Name:"
                                     :validate valid-name?
                                     :xf       keyword
                                     :path     name-path}) put-fn]
         [cs/input-row entry (merge field-cfg
                                    {:label "Label:"
                                     :path  label-path}) put-fn]
         [:div.row
          [:label.wide "Type:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      type-path
                      :xf        keyword
                      :put-fn    put-fn
                      :options   {:number "Number"
                                  :text   "Text"
                                  :time   "Time"}}]]
         (when (contains? #{:number :time} t)
           [:div.row
            [:label.wide "Aggregation:"]
            [uc/select {:entry     entry
                        :on-change uc/select-update
                        :path      agg-path
                        :xf        keyword
                        :put-fn    put-fn
                        :sort-fn   identity
                        :options   {:min  "Minimum"
                                    :max  "Maximum"
                                    :mean "Mean"
                                    :sum  "Daily Sum"
                                    :none "none"}}]])
         (when (= :number t)
           [cs/input-row entry {:label "Increment:"
                                :type  :number
                                :step  0.01
                                :path  step-path} put-fn])]))))


(defn item [{:keys [entry idx put-fn] :as params}]
  (let [items-path [:custom_field_cfg :items]
        n (count (get-in entry items-path))
        rm-click (fn []
                   (let [items (get-in entry items-path)
                         items (vec (concat (take idx items) (drop (inc idx) items)))
                         updated (assoc-in entry items-path items)]
                     (put-fn [:entry/update-local updated])))
        mv-click (fn [f _]
                   (let [items (get-in entry items-path)
                         item (get-in entry [:custom_field_cfg :items idx])
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
     [field-row params]]))


(defn custom-field-config [entry put-fn]
  (let [add-item (fn [entry]
                   (fn [_]
                     (let [updated (update-in entry [:custom_field_cfg :items] #(vec (conj % {})))]
                       (put-fn [:entry/update-local updated]))))
        tag-path [:custom_field_cfg :tag]]
    (fn [entry put-fn]
      (let [items (get-in entry [:custom_field_cfg :items])]
        [:div.habit-details
         [:h3.header
          "Custom Field Configuration"]
         [cs/input-row entry {:validate is-tag?
                              :label    "Tag:"
                              :path     tag-path} put-fn]
         [:div.row
          [:label "Active? "]
          [uc/switch {:entry entry :put-fn put-fn :path [:custom_field_cfg :active]}]]
         [:div.row
          [:h3 "Criteria"]
          [:div.add-criterion {:on-click (add-item entry)}
           [:i.fas.fa-plus]]]
         (for [[i c] (map-indexed (fn [i v] [i v]) items)]
           ^{:key i}
           [item {:entry  entry
                  :put-fn put-fn
                  :idx    i}])]))))
