(ns meins.components.photos
  (:require ["react-native" :as rn]
            ["@matthiasn/cameraroll" :as cam-roll]
            ["realm" :as realm]
            [matthiasn.systems-toolbox.component :as st]
            [meins.ui.db :as uidb]
            [clojure.string :as str]))

(when (= "android" rn/Platform.OS)
  (.request rn/PermissionsAndroid rn/PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE))

(enable-console-print!)

(defn get-img [ts]
  (when (number? ts)
    (some-> @uidb/realm-db
            (.objects "Image")
            (.filtered (str "timestamp = " ts))
            (aget 0)
            js/JSON.stringify
            js/JSON.parse
            js->clj)))

(defn camroll->image [item]
  (let [node (:node item)
        image (:image node)
        loc (:location node)
        ts (.floor js/Math (* 1000 (:timestamp node)))]
    {:timestamp ts
     :imported  false
     :fileName  (or (:fileName image)
                    (last (str/split (:uri image) "/")))
     :uri       (:uri image)
     :height    (:height image)
     :width     (:width image)
     :latitude  (:latitude loc)
     :longitude (:longitude loc)}))

(defn import-photos [{:keys [cmp-state msg-payload]}]
  (let [{:keys [n]} msg-payload
        params (clj->js {:first      n
                         :assetType  "Photos"})
        realm-db @uidb/realm-db
        photos-promise (.getPhotos cam-roll params)]
    (.then photos-promise
           (fn [r]
             (let [parsed (js->clj r :keywordize-keys true)
                   edges (:edges parsed)]
               (doseq [item edges]
                 (try
                   (let [data (camroll->image item)
                         data-js (clj->js data)
                         existing (get-img (:timestamp data))]
                     (when-not existing
                       (.write realm-db #(.create realm-db "Image" data-js true))))
                   (catch :default e (js/console.error e))))
               (swap! cmp-state assoc-in [:photos] parsed)))))
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:photos/import import-photos}})
