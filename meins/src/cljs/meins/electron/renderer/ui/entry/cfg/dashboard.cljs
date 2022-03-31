(ns meins.electron.renderer.ui.entry.cfg.dashboard
  (:require [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.cfg.shared :as cs]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            ["react-color" :as react-color]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug error info]]))

(def chrome-picker (r/adapt-react-class react-color/ChromePicker))

(defn habit-success [_]
  (let [habits (subscribe [:habits])
        pvt (subscribe [:show-pvt])]
    (fn [{:keys [entry idx]}]
      (let [path [:dashboard_cfg :items idx :habit]
            pvt-filter #(-> % second :habit_entry :habit :pvt not)
            habits (if @pvt
                     @habits
                     (into {} (filter pvt-filter @habits)))
            options (zipmap (keys habits)
                            (map #(eu/first-line (:habit_entry %))
                                 (vals habits)))]
        [:div
         [:h4 "Habit Success or Failure"]
         [:div.row
          [:label.wide "Habit:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      path
                      :xf        js/parseInt
                      :options   options}]]]))))

(defn color-picker [entry idx k label default-color]
  (let [color-path [:dashboard_cfg :items idx k]
        update-entry (fn [entry v]
                       (let [updated (assoc-in entry color-path v)]
                         (emit [:entry/update-local updated])))
        set-color (fn [data]
                    (let [hex (aget data "hex")
                          updated (assoc-in entry color-path hex)]
                      (emit [:entry/update-local updated])))]
    (when (and default-color (not (get-in entry color-path)))
      (update-entry entry default-color))
    [:div.row
     [:label.wide label]
     [chrome-picker {:disableAlpha     true
                     :color            (get-in entry color-path "#ccc")
                     :onChangeComplete set-color}]]))

(defn bp-chart
  [{:keys [entry idx collapsed]}]
  (let [h-path [:dashboard_cfg :items idx :h]
        mn-path [:dashboard_cfg :items idx :mn]
        mx-path [:dashboard_cfg :items idx :mx]
        sw-path [:dashboard_cfg :items idx :stroke_width]
        csw-path [:dashboard_cfg :items idx :circle_stroke_width]
        cr-path [:dashboard_cfg :items idx :circle_radius]
        glow-path [:dashboard_cfg :items idx :glow]]
    [:div
     [:h4 "Blood pressure chart"]
     (when-not collapsed
       [:div
        [cs/input-row entry {:type    :number
                             :label   "Height:"
                             :path    h-path
                             :default 130}]
        [cs/input-row entry {:label   "Min:"
                             :type    :number
                             :path    mn-path
                             :default 60}]
        [cs/input-row entry {:type    :number
                             :label   "Max:"
                             :path    mx-path
                             :default 220}]
        [cs/input-row entry {:type    :number
                             :label   "Stroke:"
                             :path    sw-path
                             :default 3}]
        [cs/input-row entry {:type    :number
                             :label   "Circle Radius:"
                             :path    cr-path
                             :default 5}]
        [cs/input-row entry {:type    :number
                             :label   "Circle Stroke:"
                             :path    csw-path
                             :default 1}]

        [color-picker entry idx :systolic_color "Systolic Stroke:" "#CA3C3C"]
        [color-picker entry idx :systolic_fill "Systolic Fill:" "#CA3C3C"]

        [color-picker entry idx :diastolic_color "Diastolic Stroke:" "#1f8dd6"]
        [color-picker entry idx :diastolic_fill "Diastolic Fill:" "#1f8dd6"]

        [:div.row
         [:label "Glow? "]
         [uc/switch {:entry entry :path glow-path}]]])]))

(defn quest-details [_]
  (let [backend-cfg (subscribe [:backend-cfg])]
    (fn [{:keys [entry idx collapsed]}]
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
            show-details (and (seq (str (get-in entry k-path)))
                              (not collapsed))
            select-q (fn [{:keys [entry xf options]}]
                       (let [xf (or xf identity)]
                         (fn [ev]
                           (let [tv (h/target-val ev)
                                 sel (if (empty? tv) tv (xf tv))
                                 updated (assoc-in entry k-path sel)
                                 updated (assoc-in updated tag-path (get options sel))]
                             (emit [:entry/update-local updated])))))]
        [:div
         [:h4 "Questionnaire"]
         [:div.row
          [:label.wide "Tag:"]
          [uc/select {:entry     entry
                      :on-change select-q
                      :path      k-path
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
                          :options   options}]]))
         (when show-details
           [cs/input-row entry {:type  :number
                                :label "Height:"
                                :path  h-path}])
         (when show-details
           [cs/input-row entry {:label "Label:"
                                :path  label-path}])
         (when show-details
           [cs/input-row entry {:label "Min:"
                                :type  :number
                                :path  mn-path}])
         (when show-details
           [cs/input-row entry {:label "Max:"
                                :type  :number
                                :path  mx-path}])
         (when show-details
           [cs/input-row entry {:label "Stroke:"
                                :type  :number
                                :path  sw-path}])
         (when show-details
           [cs/input-row entry {:label "Circle Radius:"
                                :type  :number
                                :path  cr-path}])
         (when show-details
           [cs/input-row entry {:label "Circle Stroke:"
                                :type  :number
                                :path  csw-path}])
         (when show-details
           [:div.row
            [:label "Glow? "]
            [uc/switch {:entry entry :path glow-path}]])
         (when show-details
           [color-picker entry idx :color "Stroke:"])
         (when show-details
           [color-picker entry idx :fill "Fill:"])]))))

(defn barchart-row [_]
  (let [backend-cfg (subscribe [:backend-cfg])
        pvt (subscribe [:show-pvt])]
    (fn [{:keys [entry idx collapsed]}]
      (let [custom-fields (get-in @backend-cfg [:custom-fields])
            tag-path [:dashboard_cfg :items idx :tag]
            h-path [:dashboard_cfg :items idx :h]
            mn-path [:dashboard_cfg :items idx :mn]
            mx-path [:dashboard_cfg :items idx :mx]
            show-details (and (seq (str (get-in entry tag-path)))
                              (not collapsed))
            field-path [:dashboard_cfg :items idx :field]
            tag (get-in entry tag-path)
            field (get-in entry field-path)
            fields (get-in @backend-cfg [:custom-fields tag :fields])
            field-cfg (get-in fields [field :cfg])
            custom-fields (if @pvt
                            custom-fields
                            (filter #(not (:pvt (second %))) custom-fields))]
        [:div
         [:h4 "Custom Field Bar Chart"]
         [:div.row
          [:label.wide "Tag:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      tag-path
                      :options   (map first custom-fields)}]]
         (let [fields (get-in @backend-cfg [:custom-fields tag :fields])
               options (zipmap (keys fields) (map :label (vals fields)))]
           [:div.row
            [:label.wide "Field:"]
            [uc/select {:entry     entry
                        :on-change uc/select-update
                        :path      field-path
                        :xf        keyword
                        :options   options}]])
         (when (and show-details field)
           [color-picker entry idx :color "Stroke:"])
         (when (and show-details field)
           [cs/input-row entry (merge field-cfg
                                      {:label "Min:"
                                       :path  mn-path})])
         (when (and show-details field)
           [cs/input-row entry (merge field-cfg
                                      {:label "Max:"
                                       :path  mx-path})])
         (when (and show-details field)
           [cs/input-row entry {:label "Height:"
                                :type  :number
                                :path  h-path}])]))))

(defn time-barchart-row [_]
  (let [sagas (subscribe [:sagas])]
    (fn [{:keys [entry idx collapsed]}]
      (let [saga-path [:dashboard_cfg :items idx :saga]
            h-path [:dashboard_cfg :items idx :h]
            mn-path [:dashboard_cfg :items idx :mn]
            mx-path [:dashboard_cfg :items idx :mx]
            show-details (and (seq (str (get-in entry saga-path)))
                              (not collapsed))
            saga (get-in entry saga-path)
            field-cfg {:type :time}
            sagas (into {}
                        (->> @sagas
                             (map (fn [[ts m]] [ts (:saga_name m)]))
                             (filter #(seq (second %)))))]
        [:div
         [:h4 "Recorded Time Bar Chart"]
         [:div.row
          [:label.wide "Saga:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      saga-path
                      :xf        js/parseInt
                      :options   sagas}]]
         (when (and show-details saga)
           [color-picker entry idx :color "Sucess Stroke:"])
         (when (and show-details saga)
           [color-picker entry idx :fail-color "Fail Stroke:"])
         (when (and show-details saga)
           [cs/input-row entry (merge field-cfg
                                      {:label "Min:"
                                       :path  mn-path})])
         (when (and show-details saga)
           [cs/input-row entry (merge field-cfg
                                      {:label "Max:"
                                       :path  mx-path})])
         (when (and show-details saga)
           [cs/input-row entry {:label "Height:"
                                :type  :number
                                :path  h-path}])]))))

(defn gitstats-row
  [{:keys [entry idx collapsed]}]
  (let [h-path [:dashboard_cfg :items idx :h]
        show-details (not collapsed)]
    [:div
     [:h4 "Git Stats Bar Chart"]
     (when show-details
       [color-picker entry idx :color "Stroke:"])
     (when show-details
       [cs/input-row entry {:label "Height:"
                            :type  :number
                            :path  h-path}])]))

(defn linechart-row [_]
  (let [backend-cfg (subscribe [:backend-cfg])
        pvt (subscribe [:show-pvt])]
    (fn [{:keys [entry idx collapsed]}]
      (let [custom-fields (get-in @backend-cfg [:custom-fields])
            tag-path [:dashboard_cfg :items idx :tag]
            h-path [:dashboard_cfg :items idx :h]
            sw-path [:dashboard_cfg :items idx :stroke_width]
            csw-path [:dashboard_cfg :items idx :circle_stroke_width]
            cr-path [:dashboard_cfg :items idx :circle_radius]
            field-path [:dashboard_cfg :items idx :field]
            tag (get-in entry tag-path)
            show-fields (and (get-in entry field-path)
                             (not collapsed))
            custom-fields (if @pvt
                            custom-fields
                            (filter #(not (:pvt (second %))) custom-fields))]
        [:div
         [:h4 "Custom Field Line Chart"]
         [:div.row
          [:label.wide "Tag:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      tag-path
                      :options   (map first custom-fields)}]]
         (let [fields (get-in @backend-cfg [:custom-fields tag :fields])
               options (zipmap (keys fields) (map :label (vals fields)))]
           [:div.row
            [:label.wide "Field:"]
            [uc/select {:entry     entry
                        :on-change uc/select-update
                        :path      field-path
                        :xf        keyword
                        :options   options}]])
         (when show-fields
           [color-picker entry idx :color "Stroke:"])
         (when show-fields
           [color-picker entry idx :fill "Fill:"])
         (when show-fields
           [cs/input-row entry {:label "Height:"
                                :type  :number
                                :path  h-path}])
         (when show-fields
           [cs/input-row entry {:label "Stroke:"
                                :type  :number
                                :path  sw-path}])
         (when show-fields
           [cs/input-row entry {:label "Circle Radius:"
                                :type  :number
                                :path  cr-path}])
         (when show-fields
           [cs/input-row entry {:label "Circle Stroke:"
                                :type  :number
                                :path  csw-path}])]))))

(defn item [_]
  (let [local (r/atom {:collapsed true})]
    (fn item-render [{:keys [entry idx] :as params}]
      (let [path [:dashboard_cfg :items idx :type]
            habit-type (get-in entry path)
            items-path [:dashboard_cfg :items]
            n (count (get-in entry items-path))
            rm-click (fn []
                       (let [items (get-in entry items-path)
                             items (vec (concat (take idx items) (drop (inc idx) items)))
                             updated (assoc-in entry items-path items)]
                         (emit [:entry/update-local updated])))
            mv-click (fn [f _]
                       (let [items (get-in entry items-path)
                             item (get-in entry [:dashboard_cfg :items idx])
                             items (vec (concat (take idx items) (drop (inc idx) items)))
                             items (vec (concat (take (f idx) items)
                                                [item]
                                                (drop (f idx) items)))
                             updated (assoc-in entry items-path items)]
                         (emit [:entry/update-local updated])))
            params (merge @local params)]
        [:div.criterion
         [:i.fas.fa-trash-alt.fr {:on-click rm-click}]
         (when (and (< idx (dec n)) (> n 1))
           [:i.fas.fa-arrow-down {:on-click (partial mv-click inc)}])
         (when (pos? idx)
           [:i.fas.fa-arrow-up {:on-click (partial mv-click dec)}])
         (when-not (= :habit_success habit-type)
           [:i.fas {:class    (if (:collapsed @local)
                                "fa-chevron-double-down"
                                "fa-chevron-double-up")
                    :on-click #(swap! local update :collapsed not)}])

         (when-not habit-type
           [:div.row
            [:label "Chart Type:"]
            [uc/select {:on-change uc/select-update
                        :entry     entry
                        :path      path
                        :xf        keyword
                        :sorted-by second
                        :options   {:barchart_row  "Custom Field Bar Chart"
                                    :linechart_row "Custom Field Line Chart"
                                    :commits-chart "Git Stats Bar Chart"
                                    :habit_success "Habit Success"
                                    :questionnaire "Questionnaire"
                                    :bp_chart      "Blood Pressure"
                                    :time_barchart "Recorded Time Bar Chart"}}]])
         (when (= :habit_success habit-type)
           [habit-success params])
         (when (= :bp_chart habit-type)
           [bp-chart params])
         (when (= :commits-chart habit-type)
           [gitstats-row params])
         (when (= :barchart_row habit-type)
           [barchart-row params])
         (when (= :linechart_row habit-type)
           [linechart-row params])
         (when (= :questionnaire habit-type)
           [quest-details params])
         (when (= :time_barchart habit-type)
           [time-barchart-row params])]))))

(defonce clipboard (r/atom {}))

(defn dashboard-config [_]
  (let [add-item (fn [entry]
                   (fn [_]
                     (let [updated (update-in entry [:dashboard_cfg :items] #(vec (conj % {})))]
                       (emit [:entry/update-local updated]))))]
    (fn [entry]
      (let [items (get-in entry [:dashboard_cfg :items])
            copy-click #(swap! clipboard assoc :copy-all entry)
            paste-click (fn []
                          (let [pasted-items (get-in @clipboard [:copy-all :dashboard_cfg :items])
                                updated (update-in entry [:dashboard_cfg :items] #(vec (concat % pasted-items)))]
                            (emit [:entry/update-local updated])
                            (swap! clipboard dissoc :copy-all)))
            clipboard-item (:copy-all @clipboard)]
        [:div.habit-details
         [:h3.header
          "Dashboard Configuration"]
         [:div.row
          [:label "Active? "]
          [uc/switch {:entry entry :path [:dashboard_cfg :active]}]]
         [:div.row
          [:label "Private? "]
          [uc/switch {:entry entry :path [:dashboard_cfg :pvt]}]]
         [:div.row
          [:h3 "Criteria"]
          [:div.add-criterion {:on-click (add-item entry)}
           [:i.fas.fa-plus]]
          [:div.spacer]
          [:div.copy-dashboard
           {:on-click copy-click}
           [:i.fas.fa-copy]
           "copy all"]
          (when clipboard-item
            [:div.copy-dashboard
             {:on-click paste-click}
             [:i.fas.fa-paste]
             "paste"])]
         (for [[i _c] (map-indexed (fn [i v] [i v]) items)]
           ^{:key i}
           [item {:entry entry
                  :idx   i}])]))))
