(ns meo.ui.photos
  (:require [meo.ui.shared :refer [view text touchable-opacity cam-roll
                                   scroll image icon swipeout]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [re-frame.core :refer [reg-sub subscribe]]
            [meo.ui.colors :as c]
            [meo.helpers :as h]
            [meo.utils.parse :as p]))

(defn photos-page [local put-fn]
  (let [theme (subscribe [:active-theme])]
    (fn [local put-fn]
      (let [bg (get-in c/colors [:list-bg @theme])
            text-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])]
        [scroll {:style {:flex-direction   "column"
                         :background-color bg}}
         (for [photo (:edges (:photos @local))]
           (let [node (:node photo)
                 loc (:location node)
                 lat (:latitude loc)
                 lon (:longitude loc)
                 img (:image node)
                 ts (.floor js/Math (* 1000 (:timestamp node)))
                 save-fn #(let [filename (str (h/img-fmt ts) "_" (:filename img))
                                entry {:latitude  lat
                                       :longitude lon
                                       :location  loc
                                       :md        ""
                                       :tags      #{"#import"}
                                       :perm_tags #{"#photo"}
                                       :mentions  #{}
                                       :media     (dissoc node :location)
                                       :img_file  filename
                                       :timestamp ts}]
                            (put-fn [:entry/new entry]))
                 hide-fn #()
                 swipeout-btns [{:text            "hide"
                                 :backgroundColor "#CA3C3C"
                                 :onPress         hide-fn}
                                {:text            "add"
                                 :backgroundColor "#3CCA3C"
                                 :onPress         save-fn}]]
             ^{:key (:uri img)}
             [swipeout {:right swipeout-btns
                        :style {:margin-bottom    5
                                :background-color text-bg}}
              [view {:style {:width          "100%"
                             :display        :flex
                             :flex-direction :row}}
               [image {:style  {:width      "100%"
                                :height     160
                                :max-height 160}
                       :source {:uri (:uri img)}}]]]))
         #_[text {:style {:color       "#777"
                          :text-align  "center"
                          :font-size   10
                          :font-weight "bold"}}
            (str (dissoc (:photos @local) :edges))]]))))

(defn photos-wrapper [local put-fn]
  (fn [{:keys [screenProps navigation] :as props}]
    (let [{:keys [navigate goBack]} navigation]
      [photos-page local put-fn])))

(defn photos-tab [local put-fn theme]
  (let [get-fn #(let [params (clj->js {:first     50
                                       :assetType "Photos"})
                      photos-promise (.getPhotos cam-roll params)]
                  (.then photos-promise
                         (fn [r]
                           (let [parsed (js->clj r :keywordize-keys true)]
                             (swap! local assoc-in [:photos] parsed)))))
        header-bg (get-in c/colors [:header-tab @theme])
        text-color (get-in c/colors [:text @theme])
        list-bg (get-in c/colors [:list-bg @theme])
        header-right (fn [_]
                       [touchable-opacity {:on-press get-fn
                                           :style    {:padding-top    8
                                                      :padding-left   12
                                                      :padding-right  12
                                                      :padding-bottom 8}}
                        [text {:style {:color      "#0078e7"
                                       :text-align "center"
                                       :font-size  18}}
                         "cam roll"]])
        opts {:title            "Photos"
              :headerRight      header-right
              :headerTitleStyle {:color text-color}
              :headerStyle      {:backgroundColor header-bg}}]
    (stack-navigator
      {:photos {:screen (stack-screen (photos-wrapper local put-fn) opts)}}
      {:cardStyle {:backgroundColor list-bg}})))
