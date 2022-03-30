(ns meins.electron.renderer.ui.entry.cfg.custom-field
  (:require [meins.common.utils.parse :as p]
            [meins.electron.renderer.ui.entry.cfg.shared :as cs]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer [debug error info]]))

(defn is-tag? [s] (when (string? s) (re-find (re-pattern (str "^#" p/tag-char-cls "+$")) s)))

(defn valid-name? [s]
  (let [s (if (keyword? s) (name s) s)]
    (when (string? s) (re-find (re-pattern (str "^" p/tag-char-cls "+$")) s))))

(defn field-row [_]
  (let [backend-cfg (subscribe [:backend-cfg])]
    (fn [{:keys [entry idx]}]
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
                                     :path     name-path})]
         [cs/input-row entry (merge field-cfg
                                    {:label "Label:"
                                     :path  label-path})]
         [:div.row
          [:label.wide "Type:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      type-path
                      :xf        keyword
                      :options   {:number "Number"
                                  :text   "Text"
                                  :time   "Time"
                                  :switch "Switch"}}]]
         (when (contains? #{:number :time} t)
           [:div.row
            [:label.wide "Aggregation:"]
            [uc/select {:entry     entry
                        :on-change uc/select-update
                        :path      agg-path
                        :xf        keyword
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
                                :path  step-path}])]))))


(defn item [{:keys [entry idx] :as params}]
  (let [items-path [:custom_field_cfg :items]
        n (count (get-in entry items-path))
        rm-click (fn []
                   (let [items (get-in entry items-path)
                         items (vec (concat (take idx items) (drop (inc idx) items)))
                         updated (assoc-in entry items-path items)]
                     (emit [:entry/update-local updated])))
        mv-click (fn [f _]
                   (let [items (get-in entry items-path)
                         item (get-in entry [:custom_field_cfg :items idx])
                         items (vec (concat (take idx items) (drop (inc idx) items)))
                         items (vec (concat (take (f idx) items)
                                            [item]
                                            (drop (f idx) items)))
                         updated (assoc-in entry items-path items)]
                     (emit [:entry/update-local updated])))]
    [:div.criterion
     [:i.fas.fa-trash-alt.fr {:on-click rm-click}]
     (when (and (< idx (dec n)) (> n 1))
       [:i.fas.fa-arrow-down {:on-click (partial mv-click inc)}])
     (when (pos? idx)
       [:i.fas.fa-arrow-up {:on-click (partial mv-click dec)}])
     [field-row params]]))

(defn validate-cfg [entry backend-cfg]
  (let [tag-path [:custom_field_cfg :tag]
        tag (get-in entry tag-path)
        ts (:timestamp entry)
        res (when-let [cfg (get-in @backend-cfg [:custom-fields tag])]
              (when-not (= ts (:timestamp cfg))
                "already defined"))]
    (if res [res] [])))

(defn custom-field-config [_]
  (let [add-item (fn [entry]
                   (fn [_]
                     (let [updated (update-in entry [:custom_field_cfg :items] #(vec (conj % {})))]
                       (emit [:entry/update-local updated]))))
        tag-path [:custom_field_cfg :tag]
        backend-cfg (subscribe [:backend-cfg])]
    (fn [entry]
      (let [items (get-in entry [:custom_field_cfg :items])
            tag-err (first (validate-cfg entry backend-cfg))]
        [:div.habit-details
         [:h3.header
          "Custom Field Configuration"]
         [cs/input-row entry {:validate is-tag?
                              :label    "Tag:"
                              :path     tag-path
                              :error    tag-err} emit]
         [:div.row
          [:label "Active? "]
          [uc/switch {:entry entry :path [:custom_field_cfg :active]}]]
         [:div.row
          [:label "Private? "]
          [uc/switch {:entry entry :path [:custom_field_cfg :pvt]}]]
         [:div.row.space-between
          [:h3 "Fields"]
          [:div.add-criterion {:on-click (add-item entry)}
           [:i.fas.fa-plus]]
          [:div.spacer]]
         (for [[i _c] (map-indexed (fn [i v] [i v]) items)]
           ^{:key i}
           [item {:entry  entry
                  :idx    i}])]))))
