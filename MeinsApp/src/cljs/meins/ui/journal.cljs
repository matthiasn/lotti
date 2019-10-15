(ns meins.ui.journal
  (:require ["@matthiasn/react-native-audio-recorder-player" :default rn-audio-recorder-player]
            ["react-navigation" :refer [createAppContainer]]
            ["react-navigation-stack" :refer [createStackNavigator]]
            ["react-navigation-transitions" :refer [fadeIn]]
            [cljs-bean.core :refer [->clj ->js bean]]
            [cljs.reader :as rdr]
            [clojure.pprint :as pp]
            [clojure.string :as s]
            [glittershark.core-async-storage :as as]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.common.utils.parse :as p]
            [meins.helpers :as h]
            [meins.ui.db :as uidb :refer [emit]]
            [meins.ui.editor :as ed]
            [meins.ui.elements.mapbox :as mb]
            [meins.ui.shared :refer [alert fa-icon flat-list image keyboard-avoiding-view platform-os
                                     scroll search-bar status-bar text text-input touchable-opacity
                                     view virtualized-list]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [taoensso.timbre :refer-macros [debug error info]]))

(defn get-entry [ts]
  (when (number? ts)
    (some-> @uidb/realm-db
            (.objects "Entry")
            (.filtered (str "timestamp = " ts))
            (aget 0 "edn")
            rdr/read-string)))

(defn list-item [_ts _navigate]
  (let [theme (subscribe [:active-theme])
        global-vclock (subscribe [:global-vclock])
        cfg (subscribe [:cfg])]
    (fn list-item-render [ts navigate]
      @global-vclock
      (let [text-bg (get-in styles/colors [:text-bg @theme])
            bg (get-in styles/colors [:list-bg @theme])
            text-color (get-in styles/colors [:text @theme])
            show-pvt (:show-pvt @cfg)
            entry (get-entry ts)
            to-detail #(do (emit [:entry/detail {:timestamp ts}])
                           (navigate "Detail"))
            {:keys [md]} entry
            md (if (> (count md) 100)
                 (str (subs md 0 100) "...")
                 md)
            delete #(emit [:entry/persist (assoc-in entry [:deleted] true)])]
        (when (or (not (or (:pvt entry)
                           (:pvt (:story entry))
                           (-> entry :story :saga :pvt)
                           (contains? (:tags entry) "#pvt")
                           (contains? (:perm_tags entry) "#pvt")))
                  show-pvt)
          [view {:style {:flex             1
                         :margin-bottom    4
                         :flex-direction   :row
                         :background-color bg
                         :width            "100%"}}
           [touchable-opacity {:on-press to-detail
                               :style    {:display         "flex"
                                          :flex-direction  "column"
                                          :width           "100%"
                                          :justify-content "space-between"}}
            [view {:style {:flex             1
                           :flex-direction   :column
                           :background-color text-bg
                           :margin-top       4
                           :margin-bottom    8
                           :border-radius    styles/border-radius
                           :padding-bottom   4
                           :width            "auto"}}
             (when-let [media (:media entry)]
               [image {:style  {:width                   "auto"
                                :border-top-left-radius  18
                                :border-top-right-radius 18
                                :height                  300}
                       :source {:uri (-> media :image :uri)}}])
             (when-let [spotify (:spotify entry)]
               [image {:style      {:height 150
                                    :width  "100%"}
                       :resizeMode "contain"
                       :source     {:uri (:image spotify)}}])
             [view {:style {:padding-top    6
                            :height         22
                            :padding-left   22
                            :padding-right  16
                            :padding-bottom 2}}
              [text {:style {:color         text-color
                             :opacity       0.68
                             :text-align    :right
                             :font-size     12
                             :font-family   :Montserrat-Regular
                             :padding-right 3
                             :font-weight   "100"}}
               (h/hh-mm ts)]]
             (if-let [spotify (:spotify entry)]
               [view {:style {:padding-top    1
                              :padding-left   4
                              :padding-right  4
                              :padding-bottom 4}}
                [text {:style {:background-color text-bg
                               :color            text-color
                               :text-align       :left
                               :font-weight      :bold
                               :font-family      :Montserrat-SemiBold
                               :font-size        12}}
                 (:name spotify)]
                [text {:style {:background-color text-bg
                               :color            text-color
                               :text-align       :left
                               :font-size        12
                               :font-family      :Montserrat-Regular
                               :padding-top      1}}
                 (->> (:artists spotify)
                      (map :name)
                      (interpose ", ")
                      (apply str))]]
               [view {:style {:padding-top    1
                              :padding-left   22
                              :padding-right  16
                              :padding-bottom 15
                              :margin-top     3}}
                [text {:style {:color       text-color
                               :text-align  :left
                               :font-size   15
                               :line-height 22
                               :font-family :Montserrat-Regular}}
                 md]])]]])))))

(defn render-item [navigate]
  (fn [item]
    (let [item (js->clj item :keywordize-keys true)
          entry (:item item)
          ts (:timestamp entry)]
      (r/as-element [list-item ts navigate]))))

(defn search-field [local]
  (let [theme (subscribe [:active-theme])
        on-change-text #(swap! local assoc-in [:jrn-search] %)
        on-clear-text #(swap! local assoc-in [:jrn-search] "")]
    (fn [_local]
      (let [light-theme (= :light @theme)
            search-field-bg (get-in styles/colors [:search-field-bg @theme])
            header-tab-bg (get-in styles/colors [:header-tab @theme])
            pt (if (= platform-os "ios") 40 10)]
        [view {:style {:background-color header-tab-bg
                       :padding-top      pt}}
         [search-bar {:placeholder         "search..."
                      :lightTheme          light-theme
                      :on-change-text      on-change-text
                      :on-clear-text       on-clear-text
                      :value               (:jrn-search @local)
                      :keyboard-type       "twitter"
                      :keyboardAppearance  (if light-theme "light" "dark")
                      :inputStyle          {:font-family "Montserrat-Regular"}
                      :inputContainerStyle {:backgroundColor search-field-bg
                                            :border-radius   styles/search-border-radius}
                      :containerStyle      {:backgroundColor   "transparent"
                                            :borderTopWidth    0
                                            :padding-top       8
                                            :padding-bottom    8
                                            :padding-left      2
                                            :padding-right     2
                                            :borderBottomWidth 0}}]]))))

(defn journal [_]
  (let [theme (subscribe [:active-theme])
        global-vclock (subscribe [:global-vclock])
        local (r/atom {:jrn-search ""})
        realm-db @uidb/realm-db]
    (fn [{:keys [navigation] :as props}]
      (let [{:keys [navigate] :as n} (js->clj navigation :keywordize-keys true)
            res (some-> realm-db
                        (.objects "Entry")
                        (.filtered (str "md CONTAINS[c] \"" (:jrn-search @local) "\""))
                        (.sorted "timestamp" true)
                        (.slice 0 1000))
            as-array (clj->js (map (fn [ts] {:timestamp (.-timestamp ts)}) res))
            bg (get-in styles/colors [:list-bg @theme])]
        @global-vclock
        [view {:style {:flex             1
                       :height           "100%"
                       :padding-left     18
                       :padding-right    16
                       :background-color bg}}
         [status-bar {:barStyle "light-content"}]
         [search-field local]
         [flat-list {:style        {:flex           1
                                    :padding-bottom 50
                                    :width          "100%"}
                     :keyExtractor (fn [item] (aget item "timestamp"))
                     :data         as-array
                     :render-item  (render-item navigate)}]]))))

(defn entry-detail [_]
  (let [entry-detail (subscribe [:entry-detail])
        theme (subscribe [:active-theme])
        cfg (subscribe [:cfg])
        player-state (r/atom {:pos    0
                              :status :paused})
        recorder-player (rn-audio-recorder-player.)
        entry-local (r/atom {:entry {}})]
    (fn [{:keys [navigation] :as _props}]
      (let [{:keys [navigate _goBack] :as _nav} (js->clj navigation :keywordize-keys true)
            entry (get-entry (:timestamp @entry-detail))
            bg (get-in styles/colors [:list-bg @theme])
            text-bg (get-in styles/colors [:text-bg @theme])
            text-color (get-in styles/colors [:text @theme])
            save-fn (fn []
                      (let [updated (p/parse-entry (:md @entry-local))]
                        (emit [:entry/persist (merge entry updated)])
                        (reset! entry-local {})
                        (navigate "Journal")))
            cancel-fn (fn [] (navigate "Journal"))
            pt (if (= platform-os "ios") 40 10)]
        ;(reset! nav navigation)
        [view {:style {:display          "flex"
                       :flex-direction   "column"
                       :height           "100%"
                       :background-color bg
                       :padding-top      pt}}
         [status-bar {:barStyle "light-content"}]
         [ed/header save-fn cancel-fn "Edit"]
         [keyboard-avoiding-view {:behavior "padding"
                                  :style    {:display         "flex"
                                             :flex-direction  "column"
                                             :justify-content "space-between"
                                             :width           "100%"
                                             :flex            1
                                             :align-items     "center"}}
          [scroll {:style {:flex-direction "column"
                           :min-height     250
                           :padding-left   18
                           :padding-right  16
                           :width          "100%"
                           :padding-bottom 10}}
           [view {:border-radius    styles/border-radius
                  :background-color text-bg}
            [view {:display         :flex
                   :flex-direction  :row
                   :justify-content :center
                   :padding-top     7
                   :opacity         0.68}
             [text {:style {:color       text-color
                            :text-align  "center"
                            :font-family "Montserrat-SemiBold"
                            :font-size   12}}
              (s/upper-case
                (h/entry-date-fmt (:timestamp entry)))]
             [text {:style {:color       text-color
                            :text-align  "center"
                            :margin-left 12
                            :font-family "Montserrat-Regular"
                            :font-size   12}}
              (h/hh-mm (:timestamp entry))]]
            (if-let [spotify (:spotify entry)]
              [view {:style {:display          "flex"
                             :flex-direction   "column"
                             :background-color "white"}}
               [image {:style      {:flex             3
                                    :background-color "black"
                                    :min-height       300
                                    :max-height       600
                                    :width            "100%"}
                       :resizeMode "contain"
                       :source     {:uri (:image spotify)}}]
               [text {:style {:background-color text-bg
                              :color            text-color
                              :text-align       "left"
                              :font-family      "Montserrat-SemiBold"
                              :font-size        12
                              :padding-left     12
                              :padding-top      4}}
                (:name spotify)]
               [text {:style {:background-color text-bg
                              :color            text-color
                              :text-align       "left"
                              :font-size        12
                              :padding-left     12
                              :font-family      "Montserrat-Regular"
                              :padding-top      1
                              :padding-bottom   4}}
                (->> (:artists spotify)
                     (map :name)
                     (interpose ", ")
                     (apply str))]]
              [text-input {:style              {:flex              2
                                                :font-weight       "100"
                                                :padding           16
                                                :font-size         15
                                                :max-height        400
                                                :min-height        100
                                                :background-color  text-bg
                                                :margin-bottom     5
                                                :border-radius     styles/border-radius
                                                :textAlignVertical :top
                                                :font-family       :Montserrat-Regular
                                                :color             text-color
                                                :width             "100%"}
                           :multiline          true
                           :default-value      (:md entry "")
                           :keyboard-type      "twitter"
                           :keyboardAppearance (if (= @theme :dark) "dark" "light")
                           :on-change-text     (fn [text]
                                                 (swap! entry-local assoc-in [:md] text))}])
            (when-let [media (:media entry)]
              [image {:style      {:flex             3
                                   :background-color "black"
                                   :min-height       300
                                   :max-height       600
                                   :width            "100%"}
                      :resizeMode "contain"
                      :source     {:uri (-> media :image :uri)}}])
            [mb/map-elem entry]
            (when-let [audio-file (:audio_file entry)]
              (let [status (:status @player-state)
                    prefix (when (= "android" platform-os)
                             "/data/data/com.matthiasn.meins/")
                    pos (h/mm-ss (.floor js/Math (:pos @player-state)))
                    listener-cb (fn [e]
                                  (let [ev (->clj e)
                                        pos (.-current_position e)]
                                    (info ev)
                                    (swap! player-state assoc-in [:pos] pos)))
                    play (fn [_]
                           (.startPlayer recorder-player (str prefix audio-file))
                           (.addPlayBackListener recorder-player listener-cb)
                           (swap! player-state assoc-in [:status] :play))
                    stop (fn [_]
                           (.stopPlayer recorder-player)
                           (.removePlayBackListener recorder-player)
                           (swap! player-state assoc-in [:status] :paused))]
                [touchable-opacity {:on-press (if (= :play status) stop play)
                                    :style    {:margin         10
                                               :display        "flex"
                                               :flex-direction "row"}}
                 [fa-icon {:name  "microphone"
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
           (when (:entry-pprint @cfg)
             [text {:style {:margin-top 4
                            :color      "white"
                            :text-align "left"
                            :font-size  8}}
              (with-out-str (pp/pprint entry))])]]]))))

(def journal-stack
  (createStackNavigator
    (clj->js {:Journal {:screen (r/reactify-component journal)}
              :Detail  {:screen (r/reactify-component entry-detail)}})
    (clj->js {:headerMode               "none"
              :defaultNavigationOptions {:headerStyle {:backgroundColor   "#445"
                                                       :borderBottomWidth 0}}
              :transitionConfig         (fn [] (fadeIn 200))})))
