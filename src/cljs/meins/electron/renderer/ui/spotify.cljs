(ns meins.electron.renderer.ui.spotify
  (:require [clojure.string :as s]
            [meins.electron.renderer.graphql :as gql]
            [meins.electron.renderer.helpers :as h]
            [meins.common.utils.misc :as m]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug error info]]))

(defn gql-query [n]
  (let [queries [[:spotify
                  {:search-text "#spotify"
                   :n           n}]]
        query (gql/tabs-query queries false true)]
    (emit [:gql/query {:q        query
                       :id       :spotify
                       :res-hash nil
                       :prio     11}])))

(defn count-spotify [items]
  (let [local (atom {:uris #{}})]
    (doseq [item (filter :spotify items)]
      (let [uri (-> item :spotify :uri)]
        (swap! local update-in [:id-cnt uri :played_cnt] #(if (number? %) (inc %) 1))
        (swap! local assoc-in [:by-cnt uri] (let [n (get-in @local [:id-cnt uri :played_cnt])]
                                              (assoc-in item [:spotify :played_cnt] n)))))
    @local))

(defn menu-view [_local]
  [:div.menu
   [:div.menu-header
    [:h2 "Songs I listened to on Spotify"]]])

(defn spotify-view []
  (let [local (r/atom {:img-size 120})
        change (fn [ev]
                 (info (h/target-val ev) @local)
                 (swap! local assoc :img-size (js/parseInt (h/target-val ev))))
        gql-res (subscribe [:gql-res2])
        ; one image image for any number of times a song was played
        entries (reaction (->> @gql-res
                               :spotify
                               :res
                               vals
                               count-spotify))
        sorted (reaction
                 (sort-by #(-> % second :spotify :played_cnt)
                          (:by-cnt @entries)))
        cmp-did-mount (fn [_props] (gql-query 2000))
        will-unmount (fn [] (gql-query 0))
        change-search #(swap! local assoc :search (h/target-val %))
        render (fn [_props]
                 (let [img-size (:img-size @local)
                       search-filter
                       (fn [[_ entry]]
                         (let [spt (:spotify entry)]
                           (s/includes?
                             (m/lower-case (str (map :name (:artists spt))
                                                (:name spt)))
                             (m/lower-case (str (:search @local))))))]
                   [:div.spotify-list
                    [:div.controls
                     [:div.size
                      [:strong "Image size:"]
                      [:input {:type      :range
                               :min       40
                               :max       400
                               :value     img-size
                               :on-change change}]]
                     [:div.spotify-search
                      [:i.fas.fa-search]
                      [:input {:on-change change-search}]]]
                    (for [[_ts entry] (reverse (filter search-filter @sorted))]
                      [:span.img-container.tooltip
                       {:key (:timestamp entry)}
                       [:img {:on-click #(emit [:spotify/play {:uri (-> entry :spotify :uri)}])
                              :src      (:image (:spotify entry))
                              :style    {:width  img-size
                                         :height img-size}}]
                       [:span.cnt (:played_cnt (:spotify entry))]
                       [:div.tooltiptext
                        [:div.title (-> entry :spotify :name)]
                        [:div.artist (->> (:artists (:spotify entry))
                                          (map :name)
                                          (interpose ", ")
                                          (apply str))]]])]))
        spotify (r/create-class {:component-did-mount    cmp-did-mount
                                 :component-will-unmount will-unmount
                                 :reagent-render         render})]
    (fn spotify-render [_put-fn]
      [:div.flex-container
       [menu-view local]
       [spotify {}]])))
