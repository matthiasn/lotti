(ns meins.electron.renderer.ui.help
  (:require [markdown.core :as md]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug error info]]))

(defn help []
  (let [manual (subscribe [:manual])]
    (fn []
      (let [content (:md @manual)
            html (md/md->html content)]
        [:div.manual
         [:div.md {:dangerouslySetInnerHTML {:__html html}}]]))))