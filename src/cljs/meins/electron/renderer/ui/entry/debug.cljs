(ns meins.electron.renderer.ui.entry.debug
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [taoensso.timbre :refer-macros [info error debug]]
            [clojure.data :as cd]
            ["electron" :refer [clipboard]]
            [moment]
            [meins.electron.renderer.ui.data-explorer :as dex]))

(defn debug-view [entry new-entry local]
  (let [click #(.writeText clipboard (pr-str entry))]
    (when (:debug @local)
      [:div.debug
       [:span.btn.start-stop {:on-click click
                              :style    {:padding   16
                                         :font-size 16}}
        [:i.fa.far.fa-clipboard]]
       [:h3 "from backend"]
       [dex/data-explorer2 entry]
       [:h3 "@new-entry"]
       [dex/data-explorer2 @new-entry]
       [:h3 "diff"]
       [dex/data-explorer2 (cd/diff entry @new-entry)]])))
