(ns meins.ios.photos
  (:require [clojure.pprint :as pp]
            ["react-native" :as rn]
            ["@matthiasn/cameraroll" :as cam-roll]
            ["realm" :as realm]
            [matthiasn.systems-toolbox.component :as st]
            [meins.ui.shared :refer [alert]]
            [meins.ui.db :as uidb]))

(enable-console-print!)

(defn camroll->image [item]
  (let [node (:node item)
        image (:image node)
        loc (:location node)
        ts (.floor js/Math (* 1000 (:timestamp node)))
        data {:timestamp ts
              :imported  false
              :fileName  (:fileName image)
              :uri       (:uri image)
              :height    (:height image)
              :width     (:width image)
              :latitude  (:latitude loc)
              :longitude (:longitude loc)}]
    (clj->js data)))

(defn import-photos [{:keys [cmp-state msg-payload]}]
  (let [{:keys [n]} msg-payload
        params (clj->js {:first      n
                         :groupTypes "All"
                         :assetType  "Photos"})
        realm-db @uidb/realm-db
        photos-promise (.getPhotos cam-roll params)]
    (.then photos-promise
           (fn [r]
             (let [parsed (js->clj r :keywordize-keys true)
                   edges (:edges parsed)]
               (doseq [item edges]
                 (try
                   (.write realm-db #(.create realm-db "Image" (camroll->image item) true))
                   (catch :default e (js/console.error e))))
               (swap! cmp-state assoc-in [:photos] parsed)))))
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:photos/import import-photos}})
