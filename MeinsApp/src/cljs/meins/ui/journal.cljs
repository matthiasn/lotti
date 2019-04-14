(ns meins.ui.journal
  (:require-macros [cljs.core.async.macros :refer [go]])
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [meins.helpers :as h]
            [glittershark.core-async-storage :as as]
            [cljs.core.async :refer [<!]]
            [meins.ui.colors :as c]
            [meins.ui.db :refer [emit]]
            [reagent.ratom :refer-macros [reaction]]
            [meins.ui.shared :refer [view text text-input scroll search-bar flat-list
                                     #_map-view #_mapbox-style-url #_point-annotation
                                     #_icon image logo-img #_swipeout keyboard-avoiding-view
                                     touchable-opacity settings-list settings-list-item
                                     rn-audio-recorder-player alert]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [clojure.pprint :as pp]
            [meins.utils.parse :as p]
            [meins.ui.db :as uidb]))

(defn map-url [latitude longitude]
  (str "http://staticmap.openstreetmap.de/staticmap.php?center="
       latitude "," longitude "&zoom=17&size=240x240&maptype=mapnik"
       "&markers=" latitude "," longitude ",lightblue"))

(defn list-item [ts navigate]
  (let [theme (subscribe [:active-theme])
        local (r/atom {})
        realm-db @uidb/realm-db]
    (fn list-item-render [ts navigate]
      (let [entry (-> (.objects realm-db "Entry")
                      (.filtered (str "timestamp = " ts))
                      (aget 0 "edn")
                      cljs.reader/read-string)]
        (swap! local assoc-in [:entry] entry))
      (let [text-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])
            entry (:entry @local)
            to-detail #(do (emit [:entry/detail {:timestamp ts}])
                           (navigate "entry"))
            {:keys [latitude longitude md]} entry
            md (if (> (count md) 100)
                 (str (subs md 0 100) "...")
                 md)
            delete #(emit [:entry/persist
                           (assoc-in (:entry @local) [:deleted] true)])]
        [view {:style {:flex             1
                       :margin-top       4
                       :flex-direction   :row
                       :background-color text-bg
                       :width            "100%"}}
         [touchable-opacity {:on-press to-detail
                             :style    {:display         "flex"
                                        :flex-direction  "row"
                                        :width           "100%"
                                        :justify-content "space-between"}}
          [view {:style {:flex             1
                         :flex-direction   :column
                         :background-color text-bg
                         :padding-top      4
                         :padding-left     8
                         :padding-right    6
                         :padding-bottom   4
                         :width            "100%"}}
           [view {:style {:padding-top    2
                          :padding-left   4
                          :padding-right  4
                          :padding-bottom 2}}
            [text {:style {:color       text-color
                           :text-align  "left"
                           :font-size   9
                           :font-weight "100"}}
             (h/format-time ts)]]
           [view {:style {:padding-top    1
                          :padding-left   4
                          :padding-right  4
                          :padding-bottom 4}}
            [text {:style {:color       text-color
                           :text-align  "left"
                           :font-weight "normal"}}
             md]]]
          (when-let [media (:media entry)]
            [image {:style  {:width  120
                             :height 120}
                    :source {:uri (-> media :image :uri)}}])]]))))

(defn render-item [navigate]
  (fn [item]
    (let [item (js->clj item :keywordize-keys true)
          entry (:item item)
          ts (:timestamp entry)]
      (r/as-element [list-item ts navigate]))))

(defn journal [_]
  (let [theme (subscribe [:active-theme])
        global-vclock (subscribe [:global-vclock])
        local (r/atom {:jrn-search ""})
        on-change-text #(swap! local assoc-in [:jrn-search] %)
        on-clear-text #(swap! local assoc-in [:jrn-search] "")
        realm-db @uidb/realm-db]
    (fn [_]
      (let [navigate (fn [])
            res (-> (.objects realm-db "Entry")
                    (.filtered (str "md CONTAINS[c] \"" (:jrn-search @local) "\""))
                    (.sorted "timestamp" true)
                    (.slice 0 100))
            as-array (clj->js (map (fn [ts] {:timestamp (.-timestamp ts)}) res))
            search-field-bg (get-in c/colors [:search-field-bg @theme])
            bg (get-in c/colors [:list-bg @theme])
            search-container-bg (get-in c/colors [:search-bg @theme])
            header-tab-bg (get-in c/colors [:header-tab @theme])
            light-theme (= :light @theme)]
        @global-vclock
        [view {:style {:flex             1
                       :background-color bg}}
         [view {:style {:background-color header-tab-bg
                        :padding-top      40
                        :padding-bottom   6}}
          [search-bar {:placeholder    "search..."
                       :lightTheme     light-theme
                       :on-change-text on-change-text
                       :on-clear-text  on-clear-text
                       :inputStyle     {:backgroundColor search-field-bg}
                       :containerStyle {:backgroundColor   "transparent"
                                        :borderTopWidth    0
                                        :borderBottomWidth 0}}]]
         [flat-list {:style        {:flex           1
                                    :padding-bottom 50
                                    :width          "100%"}
                     :keyExtractor (fn [item] (aget item "timestamp"))
                     :data         as-array
                     :render-item  (render-item navigate)}]]))))

#_(defn entry-detail [cfg-map entry-local nav]
    (let [entry-detail (subscribe [:entry-detail])
          theme (subscribe [:active-theme])
          player-state (r/atom {:pos    0
                                :status :paused})
          recorder-player (rn-audio-recorder-player.)]
      (fn [{:keys [screenProps navigation] :as props}]
        (go (try
              (let [ts (:timestamp @entry-detail)
                    entry (second (<! (as/get-item ts)))]
                (swap! entry-local assoc-in [:entry] entry)
                (swap! entry-local assoc-in [:ts] ts))
              (catch js/Object e
                (alert [:debug/error {:msg e}]))))
        (let [{:keys [navigate goBack]} navigation
              entry (:entry @entry-local)
              bg (get-in c/colors [:list-bg @theme])
              text-bg (get-in c/colors [:text-bg @theme])
              item-bg (get-in c/colors [:text-bg @theme])
              text-color (get-in c/colors [:text @theme])
              latitude (:latitude entry)
              longitude (:longitude entry)]
          (reset! nav navigation)
          [keyboard-avoiding-view {:behavior "padding"
                                   :style    {:display          "flex"
                                              :flex-direction   "column"
                                              :justify-content  "space-between"
                                              :background-color text-bg
                                              :width            "100%"
                                              :flex             1
                                              :align-items      "center"}}
           [scroll {:style {:flex-direction   "column"
                            :background-color bg
                            :width            "100%"
                            :padding-bottom   10}}
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
                                              :min-height       100
                                              :background-color text-bg
                                              :margin-bottom    5
                                              :color            text-color
                                              :width            "100%"}
                         :multiline          true
                         :default-value      (:md entry "")
                         :keyboard-type      "twitter"
                         :keyboardAppearance (if (= @theme :dark) "dark" "light")
                         :on-change-text     (fn [text]
                                               (swap! entry-local assoc-in [:md] text))}]
            (when-let [media (:media entry)]
              [image {:style  {:width  "100%"
                               :height 500}
                      :source {:uri (-> media :image :uri)}}])
            (when latitude
              [map-view {:centerCoordinate [longitude latitude]
                         :scrollEnabled    false
                         :rotateEnabled    false
                         :styleURL         (get mapbox-style-url (:map-style @cfg-map))
                         :style            {:width         "100%"
                                            :height        200
                                            :margin-bottom 30}
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
            (when-let [audio-file (:audio_file entry)]
              (let [status (:status @player-state)
                    pos (h/mm-ss (.floor js/Math (:pos @player-state)))
                    play (fn [_]
                           (.startPlayer recorder-player audio-file)
                           (.addPlayBackListener
                             recorder-player
                             #(swap! player-state assoc-in [:pos] (.-current_position %)))
                           (swap! player-state assoc-in [:status] :play))
                    stop (fn [_]
                           (.stopPlayer recorder-player)
                           (.removePlayBackListener recorder-player)
                           (swap! player-state assoc-in [:status] :paused))]
                [touchable-opacity {:on-press (if (= :play status) stop play)
                                    :style    {:margin         10
                                               :display        "flex"
                                               :flex-direction "row"}}
                 [icon {:name  "microphone"
                        :size  30
                        :style {:color       (if (= :play status) "#66F" "#999")
                                :margin-left 25}}]
                 [text {:style {:color       "#0078e7"
                                :font-size   30
                                :margin-left 25
                                :font-family "Courier"}}
                  (if (= :play status) "Stop" "Play")]
                 [text {:style {:font-size    30
                                :color        "#888"
                                :font-weight  "100"
                                :margin-left  50
                                :margin-right 25
                                :font-family  "Courier"}}
                  pos]]))]
           #_[text {:style {:margin-top  20
                            :margin-left 10
                            :color       text-color
                            :text-align  "left"
                            :font-size   9}}
              (with-out-str (pp/pprint entry))]]))))

#_(defn journal-tab [local theme]
    (let [header-bg (get-in c/colors [:header-tab @theme])
          text-color (get-in c/colors [:text @theme])
          list-bg (get-in c/colors [:list-bg @theme])
          entry-local (r/atom {})
          nav (r/atom {})
          save-fn #(let [updated (p/parse-entry (:md @entry-local))
                         go-back (:goBack @nav)]
                     (emit [:entry/persist (merge (:entry @entry-local) updated)])
                     (reset! entry-local {})
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
                                 [journal local navigate]))
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
         :entry   {:screen (stack-screen (entry-detail local entry-local nav)
                                         {:title            "Detail"
                                          :headerTitleStyle {:color text-color}
                                          :headerRight      header-right
                                          :headerStyle      {:backgroundColor header-bg}})}}
        {:cardStyle {:backgroundColor list-bg}})))
