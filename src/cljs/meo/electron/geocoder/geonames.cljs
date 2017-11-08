(ns meo.electron.geocoder.geonames
  (:require [taoensso.timbre :as timbre :refer-macros [info error debug]]
            [fs :refer [mkdirSync existsSync]]
            [camel-snake-kebab.extras :refer [transform-keys]]
            [camel-snake-kebab.core :refer [->kebab-case-keyword]]
            [local-reverse-geocoder :as geocoder]))

(aset js/console "log" #(info "GEOCODER" %))
(aset js/console "error" #(error "GEOCODER" %))

(defn format-geoname [geoname]
  (let [keywordized (transform-keys ->kebab-case-keyword geoname)]
    (-> keywordized
      (select-keys [:name :country-code :geo-name-id])
      (assoc-in [:admin-1-name] (get-in keywordized [:admin-1-code :name]))
      (assoc-in [:admin-2-name] (get-in keywordized [:admin-2-code :name]))
      (assoc-in [:admin-3-name] (get-in keywordized [:admin-3-code :name]))
      (assoc-in [:admin-4-name] (get-in keywordized [:admin-4-code :name])))))

(defn lookup [{:keys [msg-payload put-fn]}]
  (info "GEOCODER looking up" msg-payload)
  (let [points (clj->js msg-payload)
        callback (fn [err addresses]
                   (when err (error "GEOCODER" err))
                   (when addresses
                     (let [geoname (format-geoname (ffirst (js->clj addresses)))
                           res (assoc-in msg-payload [:geoname] geoname)]
                       (debug "GEOCODER result" msg-payload)
                       (put-fn [:geonames/res res]))))]
    (.lookUp geocoder points 1 callback)
    {}))

(defn state-fn [put-fn]
  (let [state (atom {})
        dump-dir "/tmp/geonames"]
    (info "Starting")
    (when-not (existsSync dump-dir)
      (mkdirSync dump-dir))
    (.init geocoder
           (clj->js {:dumpDirectory dump-dir
                     :load          {:admin1         true
                                     :admin2         true
                                     :admin3And4     false
                                     :alternateNames false}})
           #(info "GEOCODER started"))
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:geonames/lookup lookup}})
