(ns meo.jvm.imports.spotify
  (:require [cheshire.core :as cc]
            [clojure.tools.logging :as log]
            [clj-http.client :as hc]
            [clj-time.coerce :as c]
            [camel-snake-kebab.core :refer :all]
            [meo.jvm.file-utils :as fu]))

(defn import-spotify
  "Import recently played songs from spotify."
  [{:keys [put-fn]}]
  (log/info "Importing from Spotify.")
  (let [conf (fu/load-cfg)
        rp-url "https://api.spotify.com/v1/me/player/recently-played?access_token="
        refresh-token (:spotify-refresh-token conf)
        refresh-url (str "http://localhost:8888/refresh_token?refresh_token="
                         refresh-token)
        parser (fn [res] (cc/parse-string (:body res) #(keyword (->kebab-case %))))
        item-mapper (fn [item]
                      (let [track (:track item)
                            album (:album track)
                            images (:images album)
                            artists (map (fn [a] (select-keys a [:id :name]))
                                         (:artists track))]
                        {:name      (:name track)
                         :id        (:id track)
                         :artists   artists
                         :image     (:url (first images))
                         :played-at (:played-at item)}))
        entry-mapper (fn [item]
                       (let [ts (c/to-long (:played-at item))]
                         {:timestamp ts
                          :md        "listened on #spotify"
                          :id        (:id item)
                          :tags      #{"#spotify"}
                          :spotify   item}))
        ex-handler (fn [ex] (log/error (.getMessage ex)))
        get (fn [url handler] (hc/get url {:async? true} handler ex-handler))
        rp-handler (fn [res]
                     (let [parsed (parser res)
                           recently-played (map item-mapper (:items parsed))
                           new-entries (map entry-mapper recently-played)]
                       (log/info "obtained response from spotify")
                       (doseq [entry new-entries]
                         (put-fn [:entry/import entry]))))
        refresh-handler (fn [res]
                          (let [access-token (:access-token (parser res))
                                url (str rp-url access-token)]
                            (get url rp-handler)))]
    (get refresh-url refresh-handler))
  {})
