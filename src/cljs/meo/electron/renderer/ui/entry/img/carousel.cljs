(ns meo.electron.renderer.ui.entry.img.carousel
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer [info error debug]]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [meo.electron.renderer.helpers :as h]
            [clojure.data.avl :as avl]
            [clojure.string :as s]
            [markdown.core :as md]
            [reagent.core :as r]
            [meo.electron.renderer.graphql :as gql]
            [meo.electron.renderer.ui.entry.actions :as a]
            [clojure.string :as str]
            [clojure.set :as set]))

(defn stars-view [entry put-fn]
  (let [star (fn [idx n]
               (let [click (fn [ev]
                             (let [updated (assoc-in entry [:stars] idx)]
                               (debug "stars click" updated)
                               (put-fn [:entry/update updated])))]
                 [:i.fa-star {:class    (if (<= idx n) "fas" "fal")
                              :on-click click}]))
        stars (:stars entry 0)]
    [:span.stars
     [star 1 stars]
     [star 2 stars]
     [star 3 stars]
     [star 4 stars]
     [star 5 stars]]))

(defn gql-query [pvt search-text put-fn]
  (let [queries [[:gallery
                  {:search-text search-text
                   :n           1000}]]
        query (gql/tabs-query queries false pvt)]
    (put-fn [:gql/query {:q        query
                         :id       :gallery
                         :res-hash nil
                         :prio     11}])))

(defn image-view
  "Renders image view. Uses resized and properly rotated image endpoint
   when JPEG file requested."
  [album-ts entry locale local put-fn]
  (let [cfg (subscribe [:cfg])]
    (fn [album-ts entry locale local put-fn]
      (when-let [file (:img_file entry)]
        (let [fullscreen (:fullscreen @local)
              resized-rotated (if fullscreen (h/thumbs-2048 file) (h/thumbs-512 file))
              ts (:timestamp entry)
              external (str h/photos file)
              cfg (subscribe [:cfg])
              md (-> entry :md s/split-lines first)
              html (md/md->html md)
              toggle-expanded  (fn [_]
                                 (info :toggle-expanded)
                                 (gql-query true (str album-ts) put-fn)
                                 (put-fn [:nav/to {:page :gallery}]))
              original-filename (last (s/split (:img_rel_path entry) #"[/\\\\]"))]
          [:div.slide
           [:img {:src           resized-rotated
                  :draggable     true
                  :on-drag-start (a/drag-start-fn entry)
                  :on-drop       (a/drop-linked-fn entry cfg)
                  :on-drag-over  h/prevent-default
                  :on-drag-enter h/prevent-default}]
           (when-not fullscreen
             [:div.legend
              [:div.row
               (h/localize-datetime ts locale)
               [stars-view entry put-fn]
               [:span {:on-click toggle-expanded}
                (if fullscreen
                  [:i.fas.fa-compress]
                  [:i.fas.fa-expand])]]
              [:span original-filename]
              (when fullscreen
                [:a {:href external :target "_blank"} [:i.fas.fa-external-link-alt]])
              [:div {:dangerouslySetInnerHTML {:__html html}}]])])))))

(defn carousel [_]
  (let [locale (subscribe [:locale])]
    (fn [{:keys [filtered local put-fn selected-idx prev-click next-click
                 album-ts]}]
      (let [locale @locale
            selected (or (:selected @local) (first filtered))
            n (count filtered)
            two-or-more (< 1 n)]
        [:div
         [:div.carousel.carousel-slider {:style {:width "100%"}}
          [:div.slider-wrapper.axis-horizontal
           (when two-or-more
             [:button.control-arrow.control-prev {:on-click prev-click}])
           [image-view album-ts selected locale local put-fn]
           (when two-or-more
             [:button.control-arrow.control-next {:on-click next-click}])]
          (when two-or-more
            [:p.carousel-status (inc selected-idx) "/" n])]]))))

(defn gallery
  "Renders thumbnails of photos in linked entries. Respects private entries."
  [entry entries local-cfg put-fn]
  (let [local (r/atom {:filter #{}})
        cmp (fn [a b] (compare (:timestamp a) (:timestamp b)))
        sorted (reaction
                 (let [pivot (first entries)
                       others (sort-by :timestamp (rest entries))]
                   (concat [pivot] others)))
        avl-sort (fn [xs] (into (avl/sorted-set-by cmp) xs))
        selected (reaction (or (:selected @local)
                               (first @sorted)
                               (first (vec (avl-sort @sorted)))))
        next-click #(let [avl-sorted (avl-sort @sorted)
                          slide (avl/nearest avl-sorted > @selected)]
                      (swap! local assoc-in [:selected] (or slide
                                                            (first (vec avl-sorted)))))
        prev-click #(let [avl-sorted (avl-sort @sorted)
                          slide (avl/nearest avl-sorted < @selected)]
                      (swap! local assoc-in [:selected] (or slide
                                                            (last (vec avl-sorted)))))
        keydown (fn [ev]
                  (let [key-code (.. ev -keyCode)
                        meta-key (.-metaKey ev)
                        set-stars (fn [n]
                                    (let [selected @selected
                                          updated (assoc-in selected [:stars] n)]
                                      (debug updated)
                                      (put-fn [:entry/update updated])))]
                    (when (= key-code 37) (prev-click))
                    (when (= key-code 39) (next-click))
                    (when (and meta-key (= key-code 49)) (set-stars 1))
                    (when (and meta-key (= key-code 50)) (set-stars 2))
                    (when (and meta-key (= key-code 51)) (set-stars 3))
                    (when (and meta-key (= key-code 52)) (set-stars 4))
                    (when (and meta-key (= key-code 53)) (set-stars 5))
                    (.stopPropagation ev)))
        stop-watch #(.removeEventListener js/document "keydown" keydown)
        start-watch #(do (.addEventListener js/document "keydown" keydown)
                         (js/setTimeout stop-watch 60000))]
    (fn gallery-render [entry entries local-cfg put-fn]
      (let [sorted-filtered @sorted
            selected-idx (avl/rank-of (avl-sort sorted-filtered) @selected)]
        [:div.gallery {:on-mouse-enter start-watch
                       :on-mouse-over  start-watch
                       :on-mouse-leave stop-watch}
         [carousel {:filtered     sorted-filtered
                    :local-cfg    local-cfg
                    :local        local
                    :album-ts     (:timestamp entry)
                    :selected-idx selected-idx
                    :next-click   next-click
                    :prev-click   prev-click
                    :put-fn       put-fn}]]))))

(defn gallery-entries [entry]
  (let [res (filter :img_file (concat [entry]
                                      (:comments entry)
                                      (:linked entry)))
        album (contains? (set/union (set (:tags entry))
                                    (set (:perm_tags entry)))
                         "#album")]
    (if album res (take 1 res))))
