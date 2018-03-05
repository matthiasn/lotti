(ns meo.ui.journal
  (:require-macros [cljs.core.async.macros :refer [go]])
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [meo.helpers :as h]
            [glittershark.core-async-storage :as as]
            [cljs.core.async :refer [<!]]
            [meo.ui.colors :as c]
            [reagent.ratom :refer-macros [reaction]]
            [meo.ui.shared :refer [view text text-input scroll search-bar flat-list
                                   map-view mapbox-style-url point-annotation
                                   icon image logo-img
                                   touchable-opacity]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [clojure.string :as s]
            [clojure.pprint :as pp]
            [meo.utils.parse :as p]))

(defn list-item [ts navigate put-fn]
  (let [theme (subscribe [:active-theme])
        local (r/atom {})]
    (fn list-item-render [ts navigate put-fn]
      (go (try
            (let [entry (second (<! (as/get-item ts)))]
              (swap! local assoc-in [:entry] entry))
            (catch js/Object e
              (put-fn [:debug/error {:msg e}]))))
      (let [text-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])
            entry (:entry @local)
            to-detail #(do (put-fn [:entry/detail {:timestamp ts}])
                           (navigate "entry"))]
        [view {:style    {:flex             1
                          :background-color text-bg
                          :margin-top       10
                          :padding-top      8
                          :padding-left     10
                          :padding-right    10
                          :padding-bottom   8
                          :width            "100%"}
               :on-press #(do (put-fn [:entry/detail entry])
                              (navigate "entry"))}
         [touchable-opacity {:on-press to-detail
                             :style    {:padding-top    4
                                        :padding-left   12
                                        :padding-right  12
                                        :padding-bottom 2}}
          [text {:style {:color       text-color
                         :text-align  "center"
                         :font-size   9
                         :font-weight "100"
                         :margin-top  5}}
           (h/format-time ts)]]
         [touchable-opacity {:on-press to-detail
                             :style    {:padding-top    4
                                        :padding-left   12
                                        :padding-right  12
                                        :padding-bottom 8}}
          [text {:style {:color       text-color
                         :text-align  "left"
                         :font-weight "normal"}}
           (:md entry)]]]))))

(defn render-item [put-fn navigate]
  (fn [item]
    (let [item (js->clj item :keywordize-keys true)
          entry (:item item)
          ts (:timestamp entry)]
      (r/as-element [list-item ts navigate put-fn]))))

(defn journal [local put-fn navigate]
  (let [entries (subscribe [:entries])
        theme (subscribe [:active-theme])
        all-timestamps (subscribe [:all-timestamps])
        on-change-text #(swap! local assoc-in [:jrn-search] %)
        on-clear-text #(swap! local assoc-in [:jrn-search] "")]
    (fn [local put-fn navigate]
      (let [entries (filter (fn [[k v]]
                              (s/includes?
                                (s/lower-case (:md v))
                                (s/lower-case (str (:jrn-search @local)))))
                            @entries)
            ;as-array (clj->js (reverse (map second entries)))
            as-array (clj->js (reverse (map (fn [ts] {:timestamp ts})
                                            @all-timestamps)))
            search-field-bg (get-in c/colors [:search-field-bg @theme])
            bg (get-in c/colors [:list-bg @theme])
            search-container-bg (get-in c/colors [:search-bg @theme])
            light-theme (= :light @theme)]
        [view {:style {:flex             1
                       :background-color bg}}
         [search-bar {:placeholder    "search..."
                      :lightTheme     light-theme
                      :on-change-text on-change-text
                      :on-clear-text  on-clear-text
                      :inputStyle     {:backgroundColor search-field-bg}
                      :containerStyle {:backgroundColor search-container-bg}}]
         [flat-list {:style        {:flex           1
                                    :padding-bottom 50
                                    :width          "100%"}
                     :keyExtractor (fn [item] (aget item "timestamp"))
                     :data         as-array
                     :render-item  (render-item put-fn navigate)}]]))))

(defn entry-detail [cfg-map entry-local nav put-fn]
  (let [entry-detail (subscribe [:entry-detail])
        theme (subscribe [:active-theme])]
    (fn [{:keys [screenProps navigation] :as props}]
      (go (try
            (let [ts (:timestamp @entry-detail)
                  entry (second (<! (as/get-item ts)))]
              (swap! entry-local assoc-in [:entry] entry)
              (swap! entry-local assoc-in [:ts] ts))
            (catch js/Object e
              (put-fn [:debug/error {:msg e}]))))
      (let [{:keys [navigate goBack]} navigation
            entry (:entry @entry-local)
            bg (get-in c/colors [:list-bg @theme])
            text-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])
            latitude (:latitude entry)
            longitude (:longitude entry)]
        (reset! nav navigation)
        [scroll {:style {:flex-direction   "column"
                         :padding-top      15
                         :background-color bg
                         :padding-bottom   10}}
         [view {:style {:flex-direction   "column"
                        :padding-top      5
                        :background-color text-bg}}
          [text {:style {:color          text-color
                         :text-align     "center"
                         :font-size      8
                         :padding-bottom 5
                         :margin-top     5}}
           (h/format-time (:timestamp entry))]
          [text-input {:style              {:flex             2
                                            :font-weight      "100"
                                            :padding          16
                                            :font-size        24
                                            :max-height       400
                                            :background-color text-bg
                                            :margin-bottom    20
                                            :color            text-color
                                            :width            "100%"}
                       :multiline          true
                       :default-value      (:md entry)
                       :keyboard-type      "twitter"
                       :keyboardAppearance (if (= @theme :dark) "dark" "light")
                       :on-change-text     (fn [text]
                                             (swap! entry-local assoc-in [:md] text))}]]
         (when latitude
           [map-view {;:showUserLocation true
                      :centerCoordinate [longitude latitude]
                      :scrollEnabled    false
                      :rotateEnabled    false
                      :styleURL         (get mapbox-style-url (:map-style @cfg-map))
                      :style            {:width  "100%"
                                         :height 200}
                      :zoomLevel        15}
            [point-annotation {:coordinate [longitude latitude]}
             [view {:style {:width           24
                            :height          24
                            :alignItems      "center"
                            :justifyContent  "center"
                            :backgroundColor "white"
                            :borderRadius    12}}
              [view {:style {:width           24
                             :height          24
                             :backgroundColor "orange"
                             :borderRadius    12
                             :transform       [{:scale 0.7}]}}]]]])
         [text {:style {:margin-top  400
                        :color       text-color
                        :text-align  "center"
                        :font-weight "bold"
                        :padding     10}}
          (:md @entry-local)]
         [text {:style {:margin-top  20
                        :margin-left 10
                        :color       text-color
                        :text-align  "left"
                        :font-size   9}}
          (with-out-str (pp/pprint entry))]]))))

(defn journal-tab [local put-fn theme]
  (let [header-bg (get-in c/colors [:header-tab @theme])
        text-color (get-in c/colors [:text @theme])
        list-bg (get-in c/colors [:list-bg @theme])
        entry-local (r/atom {})
        nav (r/atom {})
        detail-view-entry (subscribe [:entry-detail])
        save-fn #(let [updated (p/parse-entry (:md @entry-local))
                       go-back (:goBack @nav)]
                   (reset! entry-local {})
                   (put-fn [:entry/persist (merge @detail-view-entry updated)])
                   (go-back))
        header-right (fn [_]
                       [touchable-opacity {:on-press save-fn
                                           :style    {:padding-top    8
                                                      :padding-left   12
                                                      :padding-right  12
                                                      :padding-bottom 8}}
                        [text {:style {:color      "#0078e7"
                                       :text-align "center"
                                       :font-size  18}}
                         "save"]])]
    (stack-navigator
      {:journal {:screen (stack-screen
                           (fn [{:keys [screenProps navigation] :as props}]
                             (let [{:keys [navigate goBack]} navigation]
                               [journal local put-fn navigate]))
                           {:headerTitleStyle {:color text-color}
                            :headerStyle      {:backgroundColor header-bg}
                            :headerTitle      (fn [{:keys [tintColor]}]
                                                [view {:style {:flex           1
                                                               :flex-direction :row}}
                                                 [image {:style  {:width  40
                                                                  :height 40}
                                                         :source logo-img}]
                                                 [text {:style {:color       text-color
                                                                :text-align  "left"
                                                                :margin-left 4
                                                                :margin-top  6
                                                                :font-size   20}}
                                                  "meo"]])})}
       :entry   {:screen (stack-screen (entry-detail local entry-local nav put-fn)
                                       {:title            "Detail"
                                        :headerTitleStyle {:color text-color}
                                        :headerRight      header-right
                                        :headerStyle      {:backgroundColor header-bg}})}}
      {:cardStyle {:backgroundColor list-bg}})))
