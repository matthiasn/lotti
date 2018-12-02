(ns meo.electron.renderer.ui.footer
  (:require [meo.electron.renderer.ui.dashboard.core :as db]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]))

(defn footer [put-fn]
  (let [local (r/atom {:days 90})]
    (fn footer-render [put-fn]
      [:div.footer
       [:div {:style {:max-height (:height @local)}}
        [db/dashboard (:days @local) put-fn]]])))
