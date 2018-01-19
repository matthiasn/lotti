(ns meo.electron.renderer.ui.config
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error]]
            [meo.electron.renderer.ui.stats :as stats]
            [meo.electron.renderer.ui.menu :as menu]
            [cljs.pprint :as pp]
            [reagent.core :as r]
            [clojure.string :as s]))

(defn custom-field-cfg [local]
  (let [stories (subscribe [:stories])
        backend-cfg (subscribe [:backend-cfg])
        story-sel (fn [ev]
                    (let [story (js/parseInt (-> ev .-nativeEvent .-target .-value))
                          sel (:selected @local)
                          path [:changes :custom-fields sel :default-story]]
                      (swap! local assoc-in path story)))
        story-sort-fn #(s/lower-case (:story-name (second %)))
        delete (fn [_]
                 (let [sel (:selected @local)]
                   (swap! local update-in [:changes :custom-fields] dissoc sel)
                   (swap! local dissoc :selected)))]
    (fn custom-field-cfg-render [local]
      (let [sel (:selected @local)
            changes (:changes @local)
            cfg (get-in changes [:custom-fields sel])
            item (get-in changes [:custom-fields sel])
            fields-path [:changes :custom-fields sel :fields]
            backend-cfg @backend-cfg]
        (when sel
          [:div.detail
           [:span.fa.fa-trash-o.tag-delete {:on-click delete}]
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
                   input-fn (fn [ev]
                              (let [text (-> ev .-nativeEvent .-target .-value)]
                                (swap! local assoc-in label-path text)))
                   type-select (fn [ev]
                                 (let [t (-> ev .-nativeEvent .-target .-value)]
                                   (swap! local assoc-in type-path t)))
                   label (:label cfg)
                   delete-field #(swap! local update-in fields-path dissoc field)]
               ^{:key field}
               [:div.field
                [:span.fa.fa-trash-o {:on-click delete-field}]
                [:div
                 [:label "Name:"]
                 [:span.name field]]
                [:div
                 [:label "Label:"]
                 [:input {:value    label
                          :on-input input-fn}]
                 (when-not (= (get-in backend-cfg (drop 1 label-path)) label)
                   [:span.warn [:span.fa.fa-exclamation] "not saved yet"])]
                [:div
                 [:label "Type:"]
                 [:select {:value     (-> cfg :cfg :type)
                           :on-change type-select}
                  [:option {:value :number} "Number"]
                  [:option {:value :text} "Text"]
                  [:option {:value :time} "Time"]]]]))
           [:pre [:code (with-out-str (pp/pprint item))]]])))))

(defn custom-fields-list [local]
  (let [stories (subscribe [:stories])
        backend-cfg (subscribe [:backend-cfg])
        select-item (fn [tag]
                      (let [select-toggle #(when-not (= % tag) tag)]
                        (when-not (:changes @local)
                          (swap! local assoc-in [:changes] @backend-cfg))
                        (swap! local update-in [:selected] select-toggle)))
        cfg (reaction (if-let [changes (:changes @local)]
                        (:custom-fields changes)
                        (:custom-fields @backend-cfg)))
        custom-fields (reaction (sort-by #(s/lower-case (first %)) @cfg))]
    (fn custom-fields-render [local]
      (let [stories @stories
            text (:search @local)
            item-filter #(s/includes? (s/lower-case (first %)) text)
            items (filter item-filter @custom-fields)
            sel (:selected @local)]
        [:div.cfg-items
         (for [[tag cfg] items]
           (let [del #(swap! local update-in [:changes :custom-fields] dissoc sel)]
             ^{:key tag}
             [:div.custom-field
              {:on-click #(select-item tag)
               :class    (when (= sel tag) "active")}
              [:span.fa.fa-trash-o {:on-click del}]
              [:h3 tag (when-let [ds (:default-story cfg)]
                         (str "   (" (get-in stories [ds :story-name]) ")"))]
              [:ul
               (for [[k v] (:fields cfg)]
                 ^{:key (str tag k)}
                 [:li (:label v)])]]))]))))

(defn config [put-fn]
  (let [local (r/atom {:search ""})
        backend-cfg (subscribe [:backend-cfg])
        input-fn (fn [ev]
                   (let [text (-> ev .-nativeEvent .-target .-value)]
                     (swap! local assoc-in [:search] text)))
        save-fn (fn [_]
                  (info "saving config")
                  (put-fn [:backend-cfg/save (:changes @local)])
                  (swap! local dissoc :changes :selected))
        cancel-fn (fn [_]
                    (info "canceling config changes")
                    (swap! local dissoc :changes :selected))
        cfg (reaction (if-let [changes (:changes @local)]
                        (:custom-fields changes)
                        (:custom-fields @backend-cfg)))
        custom-fields (reaction (sort-by #(s/lower-case (first %)) @cfg))]
    (fn config-render [put-fn]
      (let [text (:search @local)
            item-filter #(s/includes? (s/lower-case (first %)) text)
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
              [:input {:on-input input-fn}]
              (when (and (empty? items)
                         (= "#" (subs text 0 1)))
                [:span.add [:span.fa.fa-plus] "add"])]
             [custom-fields-list local]]
            [custom-field-cfg local]]
           [:div.footer [stats/stats-text]]]]]))))
