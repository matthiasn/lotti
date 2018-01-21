(ns meo.ui
  (:require [reagent.core :as r]
            [re-frame.core :refer [reg-sub subscribe]]
            [re-frame.db :as rdb]
            [meo.ui.editor :as edit]
            [meo.ui.shared :refer [view text text-input touchable-highlight btn
                                   tab-bar keyboard-avoiding-view vibration
                                   tab-bar-item app-registry]]
            [meo.ui.journal :as jrn]
            [meo.ui.settings :as ts]
            [meo.ui.health :as uh]
            [cljs.pprint :as pp]))

(reg-sub :entries (fn [db _] (:entries db)))

(defn app-root [put-fn]
  (let [local (r/atom {:cam        false
                       :active-tab :main
                       :md         (str "hello world")})
        click-fn (fn [k]
                   (fn [_]
                     (.vibrate vibration 2000)
                     (swap! local assoc-in [:active-tab] k)))]
    (fn [_put-fn]
      [keyboard-avoiding-view {:behavior "padding"
                               :style    {:display          "flex"
                                          :flex-direction   "column"
                                          :justify-content  "space-between"
                                          :background-color "#F8F8F8"
                                          :padding-top      40
                                          :flex             1
                                          :align-items      "center"}}
       [tab-bar {:style {:bar-tint-color "black"
                         :flex           1
                         :bar-style      "black"
                         :width          "100%"}}
        [tab-bar-item {:title     "Write"
                       :iconName  "pencil"
                       :on-press  (click-fn :main)
                       :selected  (= (:active-tab @local) :main)
                       :iconSize  20
                       :iconColor "#987"}
         [edit/editor local put-fn]]
        [tab-bar-item {:title     "Journal"
                       :iconName  "list"
                       :on-press  (click-fn :journal)
                       :selected  (= (:active-tab @local) :journal)
                       :iconSize  20
                       :iconColor "#987"}
         [jrn/journal local put-fn]]
        [tab-bar-item {:title     "Health"
                       :iconName  "heartbeat"
                       :on-press  (click-fn :health)
                       :selected  (= (:active-tab @local) :health)
                       :iconSize  20
                       :iconColor "#987"}
         [uh/health-page local put-fn]]
        [tab-bar-item {:title     "Photos"
                       :iconName  "film"
                       :on-press  (click-fn :film)
                       :selected  (= (:active-tab @local) :film)
                       :iconSize  20
                       :iconColor "#987"}
         [view {:style {:flex             1
                        :max-height       500
                        :background-color "orange"
                        :margin           10
                        :width            "100%"}}
          [text {:style {:font-size        16
                         :height           30
                         :color            :cyan
                         :background-color "#FFC8A2"
                         :font-weight      :bold
                         :margin-bottom    5
                         :text-align       "center"}}
           "Photos"]]]
        [tab-bar-item {:title     "Settings"
                       :iconName  "cogs"
                       :badge     5
                       :on-press  (click-fn :settings)
                       :selected  (= (:active-tab @local) :settings)
                       :iconSize  20
                       :iconColor "#987"}
         [ts/settings-page local put-fn]]]])))

(defn state-fn [put-fn]
  (let [app-root (app-root put-fn)
        register #(r/reactify-component app-root)]
    (.registerComponent app-registry "meo" register))
  {:observed rdb/app-db})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
