(ns meo.electron.renderer.ui.entry.thumbnails
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer [info error debug]]
            [clojure.data.avl :as avl]
            [meo.common.utils.misc :as u]
            [clojure.string :as s]
            [electron :refer [remote]]
            [markdown.core :as md]
            [meo.electron.renderer.helpers :as h]
            [reagent.core :as r]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [clojure.set :as set]))

(def iww-host (.-iwwHOST js/window))
(def user-data (.getPath (aget remote "app") "userData"))
(def photos (str user-data "/data/images/"))

(defn stars-view [ts put-fn]
  (let [{:keys [entry]} (eu/entry-reaction ts)
        star (fn [idx n]
               (let [click (fn [ev]
                             (let [updated (assoc-in @entry [:stars] idx)]
                               (debug "stars click" updated)
                               (put-fn [:entry/update updated])))]
                 [:i.fa-star {:class    (if (<= idx n) "fas" "fal")
                              :on-click click}]))
        stars (:stars @entry 0)]
    [:span.stars
     [star 1 stars]
     [star 2 stars]
     [star 3 stars]
     [star 4 stars]
     [star 5 stars]]))

(defn image-view
  "Renders image view. Uses resized and properly rotated image endpoint
   when JPEG file requested."
  [entry local-cfg locale local put-fn]
  (when-let [file (:img-file entry)]
    (let [resized (str "http://" iww-host "/photos2/" file "?width=2048")
          ts (:timestamp entry)
          external (str photos file)
          html (md/md->html (:md entry))
          fullscreen (fn [ev] (swap! local update-in [:fullscreen] not))]
      [:div.slide
       [:img {:src resized}]
       [:div.legend
        (h/localize-datetime-full ts locale)
        [stars-view ts put-fn]
        [:span {:on-click fullscreen}
         (if (:fullscreen @local)
           [:i.fas.fa-compress]
           [:i.fas.fa-expand])]
        [:a {:href external :target "_blank"} [:i.fas.fa-external-link-alt]]
        [:div {:dangerouslySetInnerHTML {:__html html}}]]])))

(defn thumb-view [entry selected local]
  (when-let [file (:img-file entry)]
    (let [resized (str "http://" iww-host "/photos2/" file "?width=256")
          click (fn [_] (swap! local assoc-in [:selected] entry))]
      [:li.thumb
       {:on-click click
        :class    (when (= entry selected) "selected")}
       [:img {:src resized}]])))

(defn carousel [_]
  (let [locale (subscribe [:locale])]
    (fn [{:keys [ts filtered local-cfg local put-fn avl-sorted
                 prev-click next-click]}]
      (let [fullscreen (:fullscreen @local)
            locale @locale
            selected (or (:selected @local) (first filtered))]
        (when (seq filtered)
          [:div
           [:div.carousel.carousel-slider
            {:style {:width "100%"}}
            [:button.control-arrow.control-prev {:on-click prev-click}]
            [:div.slider-wrapper.axis-horizontal
             [image-view selected local-cfg locale local put-fn]]
            [:button.control-arrow.control-next {:on-click next-click}]]
           (when fullscreen
             [:div.carousel
              [:div.thumbs-wrapper.axis-horizontal
               [:ul
                (for [entry filtered]
                  ^{:key (:timestamp entry)}
                  [thumb-view entry selected local])]]])])))))

(defn thumbnails
  "Renders thumbnails of photos in linked entries. Respects private entries."
  [entry local-cfg put-fn]
  (let [entries-map (subscribe [:entries-map])
        cfg (subscribe [:cfg])
        options (subscribe [:options])
        show-pvt? (reaction (:show-pvt @cfg))
        local (r/atom {})
        get-or-retrieve (u/find-missing-entry entries-map put-fn)
        linked-comments-set (reaction
                              (set/union
                                (set (:linked-entries-list entry))
                                (set (:comments entry))))
        with-imgs (reaction (filter :img-file
                                    (map get-or-retrieve @linked-comments-set)))
        filtered (reaction
                   (if @show-pvt?
                     @with-imgs
                     (filter (u/pvt-filter @options @entries-map) @with-imgs)))
        cmp (fn [a b] (compare (:timestamp a) (:timestamp b)))
        avl-sorted (reaction (into (avl/sorted-set-by cmp) (filter identity @filtered)))
        sorted (reaction (sort-by :timestamp @filtered))
        selected (reaction (or (:selected @local)
                               (first @filtered)))
        next-click #(let [slide (avl/nearest @avl-sorted > @selected)]
                      (swap! local assoc-in [:selected] (or slide
                                                            (first @filtered))))
        prev-click #(let [slide (avl/nearest @avl-sorted < @selected)]
                      (swap! local assoc-in [:selected] (or slide
                                                            (last @filtered))))
        keydown (fn [ev]
                  (let [key-code (.. ev -keyCode)
                        meta-key (.-metaKey ev)
                        set-stars (fn [n]
                                    (let [selected (:selected @local)
                                          updated (assoc-in selected [:stars] n)]
                                      (debug updated)
                                      (put-fn [:entry/update updated])))]
                    (debug key-code meta-key)
                    (when (= key-code 27)
                      (swap! local assoc-in [:fullscreen] false))
                    (when (and meta-key (= key-code 70))
                      (swap! local update-in [:fullscreen] not))
                    (when (= key-code 37) (prev-click))
                    (when (= key-code 39) (next-click))
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
         [carousel {:ts         ts
                    :filtered   @sorted
                    :avl-sorted avl-sorted
                    :local-cfg  local-cfg
                    :local      local
                    :next-click next-click
                    :prev-click prev-click
                    :put-fn     put-fn}]]))))
