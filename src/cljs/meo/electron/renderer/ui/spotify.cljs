(ns meo.electron.renderer.ui.spotify
  (:require [reagent.core :as r]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [cljs.nodejs :refer [process]]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.graphql :as gql]
            [clojure.pprint :as pp]))

(defn gql-query []
  (let [queries [[:spotify
                  {:search-text "#spotify"
                   :n           10000}]]
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

(defn menu-view [local]
  [:div.menu
   [:div.menu-header
    [:h2 "Songs I listened to on Spotify"]]])

(defn spotify-view []
  (let [local (r/atom {:img-size 120})
        change (fn [ev]
                 (info (h/target-val ev) @local)
                 (swap! local assoc :img-size (js/parseInt (h/target-val ev))))
        gql-res (subscribe [:gql-res2])
        ; one image per song
        entries (reaction (->> @gql-res
                               :spotify
                               :res
                               vals))
        ; one image image for any number of times a song was played
        entries2 (reaction (->> @gql-res
                                :spotify
                                :res
                                vals
                                count-spotify))
        sorted (reaction
                 (sort-by #(-> % second :spotify :played_cnt)
                          (:by-cnt @entries2)))
        cmp-did-mount (fn [props] (gql-query))
        render (fn [props]
                 (let [img-size (:img-size @local)]
                   [:div.spotify-list
                    [:div.controls
                     [:strong "Image size:"]
                     [:input {:type      :range
                              :min       40
                              :max       250
                              :value     img-size
                              :on-change change}]]
                    (for [[ts entry] (reverse @sorted)]
                      [:span.img-container.tooltip
                       {:key (:timestamp entry)}
                       [:img {:on-click #(emit [:spotify/play {:uri (-> entry :spotify :uri)}])
                              :src      (:image (:spotify entry))
                              :style    {:width  img-size
                                         :height img-size}}]
                       [:span.cnt (:played_cnt (:spotify entry))]
                       [:div.tooltiptext
                        (-> entry :spotify :name)]])]))
        spotify (r/create-class {:component-did-mount cmp-did-mount
                                 :reagent-render      render})]
    (fn spotify-render [put-fn]
      [:div.flex-container
       [menu-view local]
       [spotify {}]])))
