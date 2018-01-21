(ns meo.ui.journal
  (:require [reagent.core :as r]
            [re-frame.core :refer [reg-sub subscribe]]
            [meo.helpers :as h]
            [reagent.ratom :refer-macros [reaction]]
            [meo.ui.shared :refer [view text touchable-highlight scroll search-bar]]
            [meo.utils.parse :as p]
            [clojure.string :as s]))

(def defaults {:background-color "lightgreen"
               :padding-left     15
               :padding-right    15
               :padding-top      10
               :padding-bottom   10
               :margin-right     10})

(defn render-item [item]
  [touchable-highlight
   {:style    defaults
    :on-press #()
    :key      (:key item)}
   [text {:style {:color       "white"
                  :text-align  "center"
                  :font-weight "bold"}}
    ;(:title item)
    "Fooooooo"]])

(defn journal [local put-fn]
  (let [entries (subscribe [:entries])
        on-change-text #(swap! local assoc-in [:jrn-search] %)
        on-clear-text #(swap! local assoc-in [:jrn-search] "")
        filtered (reaction (filter (fn [[k v]]
                                     (s/includes?
                                       (s/lower-case (:md v))
                                       (s/lower-case (str (:jrn-search @local)))))
                                   @entries))]
    (fn [local put-fn]
      [view {:style {:flex 1}}
       [text {:style {:color       "#777"
                      :font-size   6
                      :text-align  "center"
                      :font-weight "bold"}}
        (str (:jrn-search @local))]
       [search-bar {:placeholder    "search..."
                    :on-change-text on-change-text
                    :on-clear-text  on-clear-text}]
       [scroll {:style {:flex           1
                        :padding-bottom 50
                        :width          "100%"}}
        (for [[ts entry] (filter (fn [[k v]]
                                   (s/includes?
                                     (s/lower-case (:md v))
                                     (s/lower-case (str (:jrn-search @local)))))
                                 @entries)]
          ^{:key ts}
          [view {:style {:flex             1
                         :background-color :white
                         :margin-top       10
                         :padding          10
                         :width            "100%"}}
           [text {:style {:color      "#777"
                          :text-align "center"
                          :font-size  8
                          :margin-top 5}}
            (h/format-time ts)]
           [text {:style {:color       "#777"
                          :text-align  "center"
                          :font-weight "bold"}}
            (:md entry)]])

        #_[flat-list
           {
            ;:data       []
            :data       (clj->js [(clj->js {:title "Title Text" :key "item1"})
                                  (clj->js {:title "Title Text 2" :key "item2"})])
            :renderItem render-item}]
        ]])))
