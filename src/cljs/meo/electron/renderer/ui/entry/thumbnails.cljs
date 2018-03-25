(ns meo.electron.renderer.ui.entry.thumbnails
  (:require [re-frame.core :refer [subscribe]]
            [react-responsive-carousel :as rrc]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer [info error]]
            [meo.common.utils.misc :as u]
            [clojure.string :as s]
            [electron :refer [remote]]
            [meo.electron.renderer.helpers :as h]
            [reagent.core :as r]
            [meo.electron.renderer.ui.entry.utils :as eu]))

(def iww-host (.-iwwHOST js/window))
(def user-data (.getPath (aget remote "app") "userData"))
(def photos (str user-data "/data/images/"))

(defn stars-view [ts put-fn]
  (let [{:keys [entry]} (eu/entry-reaction ts)
        star (fn [idx n]
               (let [click (fn [ev]
                             (let [updated (assoc-in @entry [:stars] idx)]
                               (put-fn [:entry/update updated])))]
                 [:i.fa-star {:class    (if (<= idx n) "fas" "fal")
                              :on-click click}]))]
    (fn [ts put-fn]
      (let [stars (:stars @entry 0)]
        [:span.stars
         [star 1 stars]
         [star 2 stars]
         [star 3 stars]
         [star 4 stars]
         [star 5 stars]]))))

(defn image-view
  "Renders image view. Used resized and properly rotated image endpoint
   when JPEG file requested."
  [entry local-cfg locale local put-fn]
  (when-let [file (:img-file entry)]
    (let [path (str "http://" iww-host "/photos/" file)
          resized (if (s/includes? (s/lower-case path) ".jpg")
                    (str "http://" iww-host "/photos2/" file)
                    path)
          ts (:timestamp entry)
          external (str photos file)
          fullscreen (fn [ev] (swap! local update-in [:fullscreen] not))]
      [:div
       [:img {:src resized}]
       [:p.legend
        [stars-view ts put-fn]
        (h/localize-datetime-full ts locale)
        [:span {:on-click fullscreen}
         (if (:fullscreen @local)
           [:i.fas.fa-compress]
           [:i.fas.fa-expand])]
        [:a {:href external :target "_blank"} [:i.fas.fa-external-link-alt]]]])))

(defn carousel [_]
  (let [locale (subscribe [:locale])]
    (fn [{:keys [ts filtered local-cfg local put-fn]}]
      (let [fullscreen (:fullscreen @local)]
        (when (seq filtered)
          (into
            [:> rrc/Carousel {:showThumbs        fullscreen
                              :showStatus        (> (count filtered) 1)
                              :useKeyboardArrows fullscreen
                              :selectedItem      (:selected @local)
                              :onChange          #(swap! local assoc-in [:selected] %)
                              :transitionTime    0}]
            (mapv (fn [entry] (image-view entry local-cfg @locale local put-fn))
                  (sort-by :timestamp filtered))))))))
(defn thumbnails
  "Renders thumbnails of photos in linked entries. Respects private entries."
  [entry local-cfg put-fn]
  (let [entries-map (subscribe [:entries-map])
        cfg (subscribe [:cfg])
        options (subscribe [:options])
        show-pvt? (reaction (:show-pvt @cfg))
        local (r/atom {:selected 0})
        get-or-retrieve (u/find-missing-entry entries-map put-fn)
        linked-entries-set (reaction (set (:linked-entries-list entry)))
        with-imgs (reaction (filter :img-file
                                    (map get-or-retrieve @linked-entries-set)))
        filtered (reaction
                   (if @show-pvt?
                     @with-imgs
                     (filter (u/pvt-filter @options @entries-map) @with-imgs)))
        keydown (fn [ev]
                  (let [key-code (.. ev -keyCode)
                        meta-key (.-metaKey ev)
                        set-stars (fn [n]
                                    (info :count (count @filtered))
                                    (let [selected (:selected @local)
                                          current (get (vec @filtered) selected)
                                          updated (assoc-in current [:stars] n)]
                                      (put-fn [:entry/update updated])))]
                    (info key-code meta-key)
                    (when (= key-code 27)
                      (swap! local assoc-in [:fullscreen] false))
                    (when (and meta-key (= key-code 70))
                      (swap! local update-in [:fullscreen] not))
                    (when (and meta-key (= key-code 49)) (set-stars 1))
                    (when (and meta-key (= key-code 50)) (set-stars 2))
                    (when (and meta-key (= key-code 51)) (set-stars 3))
                    (when (and meta-key (= key-code 52)) (set-stars 4))
                    (when (and meta-key (= key-code 53)) (set-stars 5))
                    (.stopPropagation ev)))
        start-watch #(.addEventListener js/document "keydown" keydown)
        stop-watch #(.removeEventListener js/document "keydown" keydown)]
    (fn thumbnail-render [entry local-cfg put-fn]
      (let [ts (:timestamp entry)]
        [:div.thumbnails {:class          (when (:fullscreen @local) "fullscreen")
                          :on-mouse-enter start-watch
                          :on-mouse-over  start-watch
                          :on-mouse-leave stop-watch}
         ^{:key (str ts (:fullscreen @local))}
         [carousel {:ts        ts
                    :filtered  @filtered
                    :local-cfg local-cfg
                    :local     local
                    :put-fn    put-fn}]]))))
