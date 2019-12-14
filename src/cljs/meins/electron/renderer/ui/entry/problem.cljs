(ns meins.electron.renderer.ui.entry.problem
  (:require ["react-color" :as react-color]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.ui-components :as uc]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug error info]]))

(defn editable-field [_ _ text]
  (fn [on-input-fn on-keydown-fn _]
    [:div.story-edit-field
     {:content-editable true
      :on-input         on-input-fn
      :on-key-down      on-keydown-fn}
     text]))

(defn input-fn [entry path]
  (fn [ev]
    (let [text (aget ev "target" "innerText")
          updated (assoc-in entry path text)]
      (info text)
      (emit [:entry/update-local updated]))))

(declare saga-select)

(def chrome-picker (r/adapt-react-class react-color/ChromePicker))

(defn color-picker [entry path label]
  (let [set-color (fn [data]
                    (let [hex (aget data "hex")
                          updated (assoc-in entry path hex)]
                      (emit [:entry/update-local updated])))]
    [:div.row
     [:label.wide label]
     [chrome-picker {:disableAlpha     true
                     :color            (get-in entry path "#ccc")
                     :onChangeComplete set-color}]]))

(defn problem-form
  "Renders fields for rendering the definition of a problem."
  [entry _local-cfg]
  (when (= (:entry_type entry) :problem)
    (let [ts (:timestamp entry)
          name-path [:problem_cfg :name]
          on-input-fn (input-fn entry name-path)
          on-keydown-fn (h/keydown-fn entry name-path)
          initial-story-name (get-in entry name-path)
          schedule-path [:problem_cfg :review_schedule]]
      (fn story-form-render [entry local-cfg]
        (let [sw-common {:entry    entry
                         :msg-type :entry/update}
              show-hide-comments #(emit [:cmd/assoc-in
                                         {:path  [:cfg :show-comments-for ts]
                                          :value %}])
              show-comments #(show-hide-comments (:query-id local-cfg))
              create-review (h/new-entry {:comment_for ts
                                          :entry_type  :problem-review} show-comments)]
          [:div.problem
           [:h2 "Problem"]
           [:label "Name:"]
           [:div.name-edit-field
            {:content-editable true
             :on-input         on-input-fn
             :on-key-down      on-keydown-fn}
            initial-story-name]
           [:div.row
            [:label "Active? "]
            [uc/switch (merge sw-common {:path [:problem_cfg :active]})]]
           [:div.row
            [:label "Private? "]
            [uc/switch (merge sw-common {:path [:problem_cfg :pvt]})]]
           [:div.row
            [:label "Review:"]
            [uc/select {:entry     entry
                        :on-change uc/select-update
                        :path      schedule-path
                        :xf        keyword
                        :options   {:weekly "weekly"}}]]
           (when (= :weekly (get-in entry schedule-path))
             [:div.row
              [:label "Weekday:"]
              [uc/select2 {:entry     entry
                           :on-change uc/select-update
                           :path      [:problem_cfg :weekday]
                           :xf        keyword
                           :options   {:Sunday    "Sunday"
                                       :Monday    "Monday"
                                       :Tuesday   "Tuesday"
                                       :Wednesday "Wednesday"
                                       :Thursday  "Thursday"
                                       :Friday    "Friday"
                                       :Saturday  "Saturday"}}]])
           [:div.row
            [:span.btn
             {:on-click create-review}
             "Add Review"]]])))))

(defn problem-review-form
  "Renders fields for rendering a problem review."
  [entry]
  (when (= (:entry_type entry) :problem-review)
    (let [conclusion-path [:problem_review :conclusion]]
      (fn story-form-render [entry]
        (let [conclusion (get-in entry conclusion-path)
              pivot #(emit [:entry/update-local
                            (assoc-in entry conclusion-path :pivot)])
              persevere #(emit [:entry/update-local
                                (assoc-in entry conclusion-path :persevere)])]
          [:div.problem
           [:h2 "Problem Review"]
           [:div.row
            [:span.btn.conclusion.pivot
             {:on-click pivot
              :class    (when (= conclusion :persevere) "gray")}
             "Pivot"]
            [:span.btn.conclusion
             {:on-click persevere
              :class    (when (= conclusion :pivot) "gray")}
             "Persevere"]]])))))
