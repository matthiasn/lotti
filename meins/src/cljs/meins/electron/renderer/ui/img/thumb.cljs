(ns meins.electron.renderer.ui.img.thumb
  (:require [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug error info]]))

(defn thumb-view [album-ts entry selected local]
  (when-let [file (:img_file entry)]
    (let [thumb (h/thumbs-256 file)
          click (fn [_] (swap! local assoc-in [:selected] entry))
          unlink (fn [_]
                   (let [timestamps [album-ts (:timestamp entry)]]
                     (emit [:entry/unlink timestamps])))]
      [:li.thumb
       {:on-click click
        :class    (when (= entry selected) "selected")}
       [:img {:src       thumb
              :draggable false}]
       [:i.fas.fa-times {:on-click unlink}]])))

(defn thumb-view2 [album-ts entry selected local]
  (when-let [file (:img_file entry)]
    (let [thumb (h/thumbs-256 file)
          click (fn [_] (swap! local assoc-in [:selected] entry))
          unlink (fn [_]
                   (let [timestamps [album-ts (:timestamp entry)]]
                     (emit [:entry/unlink timestamps])))]
      [:div.thumb
       {:on-click click
        :class    (when (= entry selected) "selected")}
       [:img {:src       thumb
              :draggable false}]
       [:i.fas.fa-times {:on-click unlink}]])))
