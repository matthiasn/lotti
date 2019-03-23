(ns meins.electron.renderer.ui.footer
  (:require [meins.electron.renderer.ui.dashboard.core :as db]

            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]))

(defn dashboard []
  (let [local (r/atom {:days     21
                       :controls true})]
    (fn dashboard-render []
      [:div.dashboard-column
       [db/dashboard @local]])))
