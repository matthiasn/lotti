(ns meo.electron.renderer.ui.help
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer [info error debug]]
            [markdown.core :as md]))

(defn help [put-fn]
  (let [manual (subscribe [:manual])]
    (fn [put-fn]
      (let [content (:md @manual)
            html (md/md->html content)]
        [:div.manual
         [:div.md {:dangerouslySetInnerHTML {:__html html}}]]))))