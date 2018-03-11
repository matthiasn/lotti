(ns meo.electron.renderer.ui.config
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error]]
            [meo.electron.renderer.ui.stats :as stats]
            [meo.electron.renderer.ui.menu :as menu]
            [meo.electron.renderer.helpers :as h]
            [cljs.pprint :as pp]
            [reagent.core :as r]
            [clojure.string :as s]
            [meo.common.specs :as specs]
            [meo.common.utils.parse :as p]
            [matthiasn.systems-toolbox.component :as stc]))

(defn lower-case [str]
  (if str (s/lower-case str) ""))

(defn custom-field-cfg [local]
  (let [stories (subscribe [:stories])
        backend-cfg (subscribe [:backend-cfg])
        story-sel (fn [ev]
                    (let [story (js/parseInt (h/target-val ev))
                          sel (:selected @local)
                          path [:changes :custom-fields sel :default-story]]
                      (swap! local assoc-in path story)))
        story-sort-fn #(lower-case (:story-name (second %)))
        valid-field-name #(re-find (re-pattern (str "^" p/tag-char-cls "+$")) %)
        new-field-input (fn [ev]
                          (let [text (h/target-val ev)]
                            (swap! local assoc-in [:new-field-input] text)))
        add-field (fn [_]
                    (let [field (keyword (:new-field-input @local))
                          sel (:selected @local)
                          path [:changes :custom-fields sel :fields field]
                          default {:label "change this"
                                   :cfg   {:type :text}}]
                      (swap! local assoc-in path default)
                      (swap! local assoc-in [:new-field-input] "")))]
    (fn custom-field-cfg-render [local]
      (let [sel (:selected @local)
            changes (:changes @local)
            cfg (get-in changes [:custom-fields sel])
            item (get-in changes [:custom-fields sel])
            fields-path [:changes :custom-fields sel :fields]
            backend-cfg @backend-cfg]
        (when (and sel item)
          [:div.detail
           [:h2 sel]
           [:div.story-line
            [:label "Story"]
            [:select {:value     (:default-story cfg "")
                      :on-change story-sel}
             [:option ""]
             (for [[ts story] (sort-by story-sort-fn @stories)]
               ^{:key ts}
               [:option {:value ts} (:story-name story)])]]
           (for [[field cfg] (:fields item)]
             (let [label-path (concat fields-path [field :label])
                   type-path (concat fields-path [field :cfg :type])
                   step-path (concat fields-path [field :cfg :step])
                   agg-path (concat fields-path [field :agg])
                   input-fn (fn [ev]
                              (let [text (h/target-val ev)]
                                (swap! local assoc-in label-path text)))
                   type-select (fn [ev]
                                 (let [t (keyword (h/target-val ev))]
                                   (swap! local assoc-in type-path t)))
                   step-select (fn [ev]
                                 (let [v (h/target-val ev)
                                       s (when (seq v) (js/parseFloat v))]
                                   (swap! local assoc-in step-path s)))
                   agg-select (fn [ev]
                                (let [v (h/target-val ev)
                                      agg (when (seq v) (keyword v))]
                                  (swap! local assoc-in agg-path agg)))
                   label (:label cfg)
                   field-type (-> cfg :cfg :type)
                   step (get-in cfg [:cfg :step] "")
                   agg (:agg cfg "")
                   delete-field #(swap! local update-in fields-path dissoc field)]
               ^{:key field}
               [:div.field
                [:span.fa.fa-trash-alt {:on-click delete-field}]
                [:div
                 [:label "Name:"]
                 [:span.name field]]
                [:div
                 [:label "Label:"]
                 [:input {:value     label
                          :on-change input-fn}]
                 (when-not (= (get-in backend-cfg (drop 1 label-path)) label)
                   [:span.warn [:span.fa.fa-exclamation] "unsaved"])]
                [:div
                 [:label "Type:"]
                 [:select {:value     field-type
                           :on-change type-select}
                  [:option {:value :number} "Number"]
                  [:option {:value :text} "Text"]
                  [:option {:value :time} "Time"]]
                 (when-not (= (get-in backend-cfg (drop 1 type-path)) field-type)
                   [:span.warn [:span.fa.fa-exclamation] "unsaved"])]
                (when (contains? #{:number :time} field-type)
                  [:div
                   [:label "Aggregation:"]
                   [:select {:value     agg
                             :on-change agg-select}
                    [:option ""]
                    [:option {:value :min} "min"]
                    [:option {:value :max} "max"]
                    [:option {:value :mean} "mean"]
                    [:option {:value :sum} "sum"]
                    [:option {:value :none} "none"]]
                   (when-not (= (get-in backend-cfg (drop 1 agg-path)) agg)
                     [:span.warn [:span.fa.fa-exclamation] "unsaved"])])
                (when (contains? #{:number} field-type)
                  [:div
                   [:label "Step:"]
                   [:select {:value     step
                             :on-change step-select}
                    [:option ""]
                    [:option {:value 0.01} "0.01"]
                    [:option {:value 0.1} "0.1"]
                    [:option {:value 0.5} "0.5"]
                    [:option {:value 1} "1"]]
                   (when-not (= (get-in backend-cfg (drop 1 step-path)) step)
                     [:span.warn [:span.fa.fa-exclamation] "unsaved"])])]))
           [:div.field
            [:label "New Field:"]
            [:input {:on-change new-field-input}]
            (when (valid-field-name (:new-field-input @local ""))
              [:span.add {:on-click add-field}
               [:span.fa.fa-plus] "add"])]
           [:pre [:code (with-out-str (pp/pprint item))]]])))))

(defn custom-fields-list [local]
  (let [stories (subscribe [:stories])
        backend-cfg (subscribe [:backend-cfg])
        select-item (fn [tag]
                      (let [select-toggle #(when-not (= % tag) tag)]
                        (when-not (:changes @local)
                          (swap! local assoc-in [:changes] @backend-cfg))
                        (swap! local assoc-in [:new-field-input] "")
                        (swap! local update-in [:selected] select-toggle)))
        cfg (reaction (if-let [changes (:changes @local)]
                        (:custom-fields changes)
                        (:custom-fields @backend-cfg)))
        custom-fields (reaction (sort-by #(lower-case (first %)) @cfg))]
    (fn custom-fields-render [local]
      (let [stories @stories
            text (:search @local)
            item-filter #(s/includes? (lower-case (first %)) text)
            items (filter item-filter @custom-fields)
            sel (:selected @local)]
        [:div.cfg-items
         (for [[tag cfg] items]
           (let [del (fn [ev]
                       (let [cf-cfg (or (:custom-fields @local)
                                        (:custom-fields @backend-cfg))
                             updated (dissoc cf-cfg sel)]
                         (swap! local assoc-in [:changes :custom-fields] updated)
                         (swap! local assoc-in [:selected] nil)))]
             ^{:key tag}
             [:div.custom-field
              {:on-click #(select-item tag)
               :class    (when (= sel tag) "active")}
              (when (= sel tag)
                [:span.fa.fa-trash-alt {:on-click del}])
              [:h3 tag (when-let [ds (:default-story cfg)]
                         (str "   (" (get-in stories [ds :story-name]) ")"))]
              [:ul
               (for [[k v] (:fields cfg)]
                 ^{:key (str tag k)}
                 [:li (:label v)])]]))]))))

(defn locale [put-fn]
  (let [cfg (subscribe [:cfg])
        locales {:de "German"
                 :en "English"
                 :fr "French"
                 :es "Spanish"}
        set-locale (fn [ev]
                     (let [sel (keyword (-> ev .-nativeEvent .-target .-value))]
                       (put-fn [:cmd/toggle-key {:path     [:cfg :locale]
                                                 :reset-to sel}])))]
    (fn [put-fn]
      [:div.locale
       [:h2 "Localization"]
       [:select {:value     (:locale @cfg :en)
                 :on-change set-locale}
        (for [[k locale-name] locales]
          ^{:key k}
          [:option {:value k} locale-name])]])))

(defn config [put-fn]
  (let [local (r/atom {:search          ""
                       :new-field-input ""})
        iww-host (.-iwwHOST js/window)
        backend-cfg (subscribe [:backend-cfg])
        input-fn (fn [ev]
                   (let [text (lower-case (h/target-val ev))]
                     (swap! local assoc-in [:search] text)))
        save-fn (fn [_]
                  (let [custom-fields (-> @local :changes :custom-fields)
                        cfg (assoc-in @backend-cfg [:custom-fields] custom-fields)]
                    (info "saving config")
                    (put-fn [:backend-cfg/save cfg])
                    (swap! local dissoc :changes :selected)))
        cancel-fn (fn [_]
                    (info "canceling config changes")
                    (swap! local dissoc :changes :selected))
        cfg (reaction (if-let [changes (:changes @local)]
                        (:custom-fields changes)
                        (:custom-fields @backend-cfg)))
        custom-fields (reaction (sort-by #(lower-case (first %)) @cfg))
        add-tag (fn [tag]
                  (fn [_ev]
                    (let [updated (assoc-in @cfg [tag] {:default-story nil
                                                        :fields        {}})]
                      (swap! local assoc-in [:changes :custom-fields] updated))))]
    (fn config-render [put-fn]
      (let [text (:search @local)
            item-filter #(s/includes? (lower-case (first %)) (s/trim text))
            items (filter item-filter @custom-fields)
            save-key-fn (fn [ev]
                          (when (and (= (.-keyCode ev) 83) (.-metaKey ev))
                            (save-fn ev)))]
        [:div.flex-container
         [:div.grid
          [:div.wrapper
           [menu/menu-view put-fn]
           [:div.single.config {:on-key-down save-key-fn}
            [:div.col
             [:h2 "Custom Fields Editor"]
             (when (and (:changes @local) (not= @backend-cfg (:changes @local)))
               [:div.save
                [:span.not-saved {:on-click save-fn}
                 [:span.fa.fa-floppy-o] " save"]
                [:span.cancel {:on-click cancel-fn}
                 [:span.fa.fa-ban] "  cancel"]])
             [:div.input-line
              [:input {:on-change input-fn}]
              (when (and (empty? items)
                         ((specs/is-tag? "#") text))
                [:span.add {:on-click (add-tag text)}
                 [:span.fa.fa-plus] "add"])]
             (when (seq text)
               [custom-fields-list local])]
            [custom-field-cfg local]
            [:div.third-col]
            [locale put-fn]]
           [:div.footer [stats/stats-text]]]]]))))
