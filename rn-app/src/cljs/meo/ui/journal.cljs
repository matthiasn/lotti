(ns meo.ui.journal
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [meo.helpers :as h]
            [meo.ui.colors :as c]
            [reagent.ratom :refer-macros [reaction]]
            [meo.ui.shared :refer [view text scroll search-bar flat-list
                                   map-view mapbox-style-url icon image logo-img
                                   touchable-highlight]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [clojure.string :as s]
            [clojure.pprint :as pp]))

(defn render-item [local put-fn navigate]
  (fn [item]
    (let [item (js->clj item :keywordize-keys true)
          entry (:item item)
          ts (:timestamp entry)
          to-detail #(do (put-fn [:entry/detail entry])
                         (navigate "entry"))]
      (r/as-element
        [view {:style    {:flex             1
                          :background-color :white
                          :margin-top       10
                          :padding          10
                          :width            "100%"}
               :on-press #(do (put-fn [:entry/detail entry])
                              (navigate "entry"))}
         [touchable-highlight {:on-press to-detail
                               :style    {:padding-top    8
                                          :padding-left   12
                                          :padding-right  12
                                          :padding-bottom 8}}
          [text {:style {:color      "#777"
                         :text-align "center"
                         :font-size  8
                         :margin-top 5}}
           (h/format-time ts)]]
         [touchable-highlight {:on-press to-detail
                               :style    {:padding-top    8
                                          :padding-left   12
                                          :padding-right  12
                                          :padding-bottom 8}}
          [text {:style {:color       "#777"
                         :text-align  "center"
                         :font-weight "bold"}}
           (:md entry)]]]))))

(defn journal [local put-fn navigate]
  (let [entries (subscribe [:entries])
        on-change-text #(swap! local assoc-in [:jrn-search] %)
        on-clear-text #(swap! local assoc-in [:jrn-search] "")]
    (fn [local put-fn navigate]
      (let [entries (filter (fn [[k v]]
                              (s/includes?
                                (s/lower-case (:md v))
                                (s/lower-case (str (:jrn-search @local)))))
                            @entries)
            as-array (clj->js (reverse (map second entries)))]
        [view {:style {:flex             1
                       :background-color c/light-gray}}
         [search-bar {:placeholder    "search..."
                      :lightTheme     true
                      :on-change-text on-change-text
                      :on-clear-text  on-clear-text
                      :inputStyle     {:backgroundColor "white"}
                      :containerStyle {:backgroundColor c/medium-gray}}]

         [flat-list {:style        {:flex           1
                                    :padding-bottom 50
                                    :width          "100%"}
                     :keyExtractor (fn [item] (aget item "timestamp"))
                     :data         as-array
                     :render-item  (render-item local put-fn navigate)}]]))))

(defn entry-detail [local put-fn]
  (let [entry-detail (subscribe [:entry-detail])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            reset-state #(do (put-fn [:state/reset]) (goBack))
            load-state #(do (put-fn [:state/load]) (goBack))
            entry @entry-detail]
        [scroll {:style {:flex-direction   "column"
                         :padding-top      10
                         :background-color c/light-gray
                         :padding-bottom   10}}

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
         (when true
           [text {:style {:margin-top  40
                          :margin-left 10
                          :color       "#555"
                          :text-align  "left"
                          :font-size   9}}
            (with-out-str (pp/pprint entry))])]))))

(defn journal-tab [local put-fn]
  (stack-navigator
    {:journal {:screen (stack-screen
                         (fn [{:keys [screenProps navigation] :as props}]
                           (let [{:keys [navigate goBack]} navigation]
                             [journal local put-fn navigate]))
                         {:headerTitle (fn [{:keys [tintColor]}]
                                         [view {:style {:flex           1
                                                        :flex-direction :row}}
                                          [image {:style  {:width  40
                                                           :height 40}
                                                  :source logo-img}]
                                          [text {:style {:color       "#555"
                                                         :text-align  "left"
                                                         :margin-left 4
                                                         :margin-top  6
                                                         :font-size   20}}
                                           "meo"]])})}
     :entry   {:screen (stack-screen (entry-detail local put-fn)
                                     {:title "Detail"})}}))
