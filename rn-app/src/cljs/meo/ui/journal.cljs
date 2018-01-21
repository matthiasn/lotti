(ns meo.ui.journal
  (:require [reagent.core :as r]
            [re-frame.core :refer [reg-sub subscribe]]
            [meo.helpers :as h]
            [reagent.ratom :refer-macros [reaction]]
            [meo.ui.shared :refer [view text scroll search-bar flat-list
                                   map-view mapbox-style-url]]
            [meo.utils.parse :as p]
            [clojure.string :as s]))

(def defaults {:background-color "lightgreen"
               :padding-left     15
               :padding-right    15
               :padding-top      10
               :padding-bottom   10
               :margin-right     10})

(defn render-item [item]
  (let [item (js->clj item :keywordize-keys true)
        entry (:item item)
        local (r/atom {:detail false})]
    (r/as-element
      [view {:style    {:flex             1
                        :background-color :white
                        :margin-top       10
                        :padding          10
                        :width            "100%"}
             :on-press #(swap! local update-in [:detail] not)
             :key      (:timestamp entry)}
       [text {:style {:color      "#777"
                      :text-align "center"
                      :font-size  8
                      :margin-top 5}}
        (h/format-time (:timestamp entry))]
       [text {:style {:color       "#777"
                      :text-align  "center"
                      :font-weight "bold"}}
        (:md entry)]
       (when (:latitude entry)
         [map-view {:showUserLocation true
                    :centerCoordinate [(:longitude entry) (:latitude entry)]
                    :scrollEnabled    false
                    :rotateEnabled    false
                    :styleURL         (get mapbox-style-url (:map-style @local))
                    :style            {:width  "100%"
                                       :height 200}
                    :zoomLevel        15}])

       (when (:detail @local)
         [text {:style {:color      "#555"
                        :text-align "center"
                        :font-size  7}}
          (str entry)])])))

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
      (let [entries (filter (fn [[k v]]
                              (s/includes?
                                (s/lower-case (:md v))
                                (s/lower-case (str (:jrn-search @local)))))
                            @entries)
            as-array (clj->js (map second entries))]
        [view {:style {:flex 1}}
         [text {:style {:color       "#777"
                        :font-size   6
                        :text-align  "center"
                        :font-weight "bold"}}
          (str (:jrn-search @local))]

         [search-bar {:placeholder    "search..."
                      :on-change-text on-change-text
                      :on-clear-text  on-clear-text}]

         [flat-list {:style       {:flex           1
                                   :padding-bottom 50
                                   :width          "100%"}
                     :data        as-array
                     :render-item render-item}]]))))
