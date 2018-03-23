(ns meo.electron.renderer.ui.entry.thumbnails
  (:require [meo.electron.renderer.ui.media :as m]
            [re-frame.core :refer [subscribe]]
            [react-responsive-carousel :as rrc]
            [reagent.ratom :refer-macros [reaction]]
            [meo.common.utils.misc :as u]
            [clojure.string :as s]
            [cljs.pprint :as pp]
            [meo.common.utils.parse :as up]
            [meo.electron.renderer.helpers :as h]
            [reagent.core :as r]))

(def iww-host (.-iwwHOST js/window))

(defn image-view
  "Renders image view. Used resized and properly rotated image endpoint
   when JPEG file requested."
  [entry query-params local-cfg locale local put-fn]
  (when-let [file (:img-file entry)]
    (let [path (str "http://" iww-host "/photos/" file)
          resized (if (s/includes? (s/lower-case path) ".jpg")
                    (str "http://" iww-host "/photos2/" file query-params)
                    path)
          tab-group (:tab-group local-cfg)
          ts (:timestamp entry)
          add-search (up/add-search (str (:timestamp entry)) tab-group put-fn)
          fullscreen (fn [ev] (swap! local update-in [:fullscreen] not))]
      [:div
       [:img {:src resized}]
       [:p.legend {:on-click fullscreen}
        [:a {:href path :target "_blank"}
         (h/localize-datetime-full ts locale)
         (if (:fullscreen @local)
           [:i.fas.fa-compress]
           [:i.fas.fa-expand])]]])))

(defn carousel [_]
  (let [locale (subscribe [:locale])]
    (fn [{:keys [ts filtered local-cfg local put-fn]}]
      (when (seq filtered)
        (into
          [:> rrc/Carousel {:showThumbs        false
                            :showStatus        (> (count filtered) 1)
                            :useKeyboardArrows true
                            :transitionTime    250}]
          (mapv (fn [entry] (image-view
                              entry "?width=600" local-cfg @locale local put-fn))
                filtered))))))

(defn thumbnails
  "Renders thumbnails of photos in linked entries. Respects private entries."
  [entry local-cfg put-fn]
  (let [entries-map (subscribe [:entries-map])
        cfg (subscribe [:cfg])
        options (subscribe [:options])
        active (reaction (:active @cfg))
        show-pvt? (reaction (:show-pvt @cfg))
        local (r/atom {})
        get-or-retrieve (u/find-missing-entry entries-map put-fn)
        escape (fn [ev]
                 (let [key-code (.. ev -keyCode)
                       meta-key (.-metaKey ev)]
                   (when (= key-code 27)
                     (swap! local assoc-in [:fullscreen] false))
                   (when (and meta-key (= key-code 70))
                     (swap! local update-in [:fullscreen] not))
                   (.preventDefault ev)))]
    (fn thumbnail-render [entry local-cfg put-fn]
      (let [ts (:timestamp entry)
            entry-active? (contains? (set (vals @active)) (:timestamp entry))
            linked-entries-set (set (:linked-entries-list entry))
            with-imgs (filter :img-file (map get-or-retrieve linked-entries-set))
            filtered (if @show-pvt?
                       with-imgs
                       (filter (u/pvt-filter @options @entries-map) with-imgs))]
        (when-not entry-active?
          [:div.thumbnails {:class (when (:fullscreen @local) "fullscreen")
                            :on-key-down escape}
           [carousel {:ts        ts
                      :filtered  filtered
                      :local-cfg local-cfg
                      :local     local
                      :put-fn    put-fn}]])))))
