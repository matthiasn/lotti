(ns meins.ios.photos
  (:require [clojure.pprint :as pp]
            ["react-native" :as rn]
            [matthiasn.systems-toolbox.component :as st]))

(enable-console-print!)

(defn import-photos [{:keys [cmp-state put-fn msg-payload]}]
  (let [{:keys [n]} msg-payload
        params (clj->js {:first     n
                         :assetType "Photos"})
        photos-promise (.getPhotos rn/cam-roll params)]
    (.then photos-promise
           (fn [r]
             (let [parsed (js->clj r :keywordize-keys true)]
               (swap! cmp-state assoc-in [:photos] parsed)))))
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:photos/import import-photos}})
