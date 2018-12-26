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

(defn menu-view []
  [:div.menu
   [:div.menu-header
    [:h2 "Songs I listened to on Spotify"]]])

(defn spotify-view []
  (let [local (atom {})
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
                          (:by-cnt @entries2)) )
        cmp-did-mount (fn [props] (gql-query))
        render (fn [props]
                 [:div.spotify
                  (for [[ts entry] (reverse @sorted)]
                    [:span.img-container.tooltip
                     [:img {:key      (:timestamp entry)
                            :on-click #(emit [:spotify/play {:uri (-> entry :spotify :uri)}])
                            :src      (:image (:spotify entry))}]
                     [:span.cnt (:played_cnt (:spotify entry))]
                     [:div.tooltiptext
                      (-> entry :spotify :name)

                      ]
                     ])])
        spotify (r/create-class {:component-did-mount cmp-did-mount
                                 :reagent-render      render})]
    (fn spotify-render [put-fn]
      [:div.flex-container.spotify
       [menu-view]
       [spotify {}]])))
