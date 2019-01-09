(ns meins.electron.renderer.ui.help
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [taoensso.timbre :refer [info error debug]]
            [markdown.core :as md]))

(defn help []
  (let [manual (subscribe [:manual])]
    (fn []
      (let [content (:md @manual)
            html (md/md->html content)]
        [:div.manual
         [:div.md {:dangerouslySetInnerHTML {:__html html}}]]))))