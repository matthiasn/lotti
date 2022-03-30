(ns meins.electron.renderer.ui.media
  (:require [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [reagent.core :as r]))

(defn imdb-view [entry]
  (when-let [imdb-id (get-in entry [:custom-fields "#imdb" :imdb-id])]
    (let [imdb (:imdb entry)
          series (:series imdb)]
      (if imdb
        [:div
         (if series
           [:h4 (:title series) " S" (:season imdb) "E" (:episode imdb)
            ": " (:title imdb) " - " (:year imdb)]
           [:h4 (:title imdb) " - " (:year imdb)])
         [:p (:actors imdb)]
         [:p (:plot imdb)]
         (when-let [series-poster (:poster series)]
           [:img {:src series-poster}])
         [:img {:src (:poster imdb)}]]
        (emit [:import/movie {:entry   entry
                              :imdb-id imdb-id}])))))

(defn spotify-view [entry]
  (when-let [spotify (get-in entry [:spotify])]
    [:div.spotify {:on-click #(emit [:spotify/play {:uri (:uri spotify)}])}
     [:div.title (:name spotify)]
     [:div.artist (->> (:artists spotify)
                       (map :name)
                       (interpose ", ")
                       (apply str))]
     [:img {:src       (:image spotify)
            :draggable false}]]))
