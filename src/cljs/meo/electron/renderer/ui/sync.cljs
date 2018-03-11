(ns meo.electron.renderer.ui.sync
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error]]
            [meo.electron.renderer.ui.stats :as stats]
            [meo.electron.renderer.ui.menu :as menu]
            [clojure.string :as s]
            [matthiasn.systems-toolbox.component :as stc]))

(defn sync [put-fn]
  (let [iww-host (.-iwwHOST js/window)]
    (fn config-render [put-fn]
      (let []
        [:div.flex-container
         [:div.grid
          [:div.wrapper
           [menu/menu-view put-fn]
           [:img {:src (str "http://" iww-host "/secrets/"
                            (stc/make-uuid) "/secrets.png")}]
           [:div.footer [stats/stats-text]]]]]))))
