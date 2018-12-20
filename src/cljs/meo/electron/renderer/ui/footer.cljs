(ns meo.electron.renderer.ui.footer
  (:require [meo.electron.renderer.ui.dashboard.core :as db]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]))

(defn dashboard [put-fn]
  (let [cfg (subscribe [:cfg])
        dashboard (reaction (:dashboard-banner @cfg))
        local (r/atom {:days     90
                       :controls true})]
    (fn dashboard-render [put-fn]
      (when @dashboard
        [:div.footer
         [:div {:style {:max-height (:height @local)}}
          [db/dashboard @local put-fn]]]))))
