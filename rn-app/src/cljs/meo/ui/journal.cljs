(ns meo.ui.journal
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [meo.helpers :as h]
            [reagent.ratom :refer-macros [reaction]]
            [meo.ui.shared :refer [view text scroll search-bar flat-list
                                   map-view mapbox-style-url]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [clojure.string :as s]))

(defn render-item [local put-fn]
  (fn [item]
    (let [item (js->clj item :keywordize-keys true)
          entry (:item item)]
      (r/as-element
        [view {:style {:flex             1
                       :background-color :white
                       :margin-top       10
                       :padding          10
                       :width            "100%"}
               :key   (:timestamp entry)}
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
            (str entry)])]))))

(defn journal [local put-fn]
  (let [entries (subscribe [:entries])
        on-change-text #(swap! local assoc-in [:jrn-search] %)
        on-clear-text #(swap! local assoc-in [:jrn-search] "")]
    (fn [local put-fn]
      (let [entries (filter (fn [[k v]]
                              (s/includes?
                                (s/lower-case (:md v))
                                (s/lower-case (str (:jrn-search @local)))))
                            @entries)
            as-array (clj->js (map second entries))]
        [view {:style {:flex 1}}
         [search-bar {:placeholder    "search..."
                      :lightTheme     true
                      :on-change-text on-change-text
                      :on-clear-text  on-clear-text}]

         [flat-list {:style       {:flex           1
                                   :padding-bottom 50
                                   :width          "100%"}
                     :data        as-array
                     :render-item (render-item local put-fn)}]]))))

(defn journal-wrapper [local put-fn]
  (fn [{:keys [screenProps navigation] :as props}]
    (let [{:keys [navigate goBack]} navigation]
      [journal local put-fn])))

(defn journal-tab [local put-fn]
  (stack-navigator
    {:journal {:screen (stack-screen (journal-wrapper local put-fn)
                                     {:title "Journal"})}}))
