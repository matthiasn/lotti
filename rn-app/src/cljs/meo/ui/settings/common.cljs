(ns meo.ui.settings.common
  (:require [reagent.core :as r]
            [meo.ui.shared :refer [view icon]]))


(defn settings-icon [icon-name color]
  (r/as-element
    [view {:style {:padding-top  14
                   :padding-left 14
                   :width        44}}
     [icon {:name  icon-name
            :size  20
            :style {:color      color
                    :text-align :center}}]]))