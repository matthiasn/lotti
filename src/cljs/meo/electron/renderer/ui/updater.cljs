(ns meo.electron.renderer.ui.updater
  (:require [reagent.core :as r]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [taoensso.timbre :refer-macros [info debug]]
            [clojure.pprint :as pp]))

(defn cancel []
  (emit [:update/status {:status :update/closed}]))

(defn cancel-btn []
  (let [cancel (fn [_]
                 (info "Cancel button clicked")
                 (cancel))]
    [:button {:on-click cancel} "cancel"]))

(defn checking []
  [:div.updater
   [:h2 "Checking for latest version of meo..."]
   [cancel-btn]])

(defn no-update [local]
  (js/setTimeout #(cancel) 12000)
  ((fn [local]
     (let [check (fn [_]
                   (info "Check button clicked")
                   (emit [:update/check]))
           check-beta (fn [_]
                        (info "Check beta versions")
                        (emit [:update/check-beta]))]

       [:div.updater
        [:h2 "You already have the latest version of meo."]
        [cancel-btn]
        " "
        [:button {:on-click check} "check"]
        " "
        [:button {:on-click check-beta} "check for beta version"]]))))

(defn update-available [status-msg]
  (let [download (fn [_] (emit [:update/download]))
        download-install (fn [_] (emit [:update/download :immediate]))
        {:keys [version releaseDate]} (:info status-msg)]
    [:div.updater
     [:h2 "New version of meo available..."]
     [:div.info
      [:div [:strong "Version: "] version]
      [:div [:strong "Release date: "] (subs releaseDate 0 10)]]
     [cancel-btn]
     " "
     [:button {:on-click download} "download"]
     " "
     [:button {:on-click download-install} "download & install"]]))

(defn downloading [status-msg local]
  (let [{:keys [total percent bytesPerSecond transferred]} (:info status-msg)
        mbs (/ (Math/floor (/ bytesPerSecond 1024 102.4)) 10)
        total (Math/floor (/ total 1024 1024))
        transferred (Math/floor (/ transferred 1024 1024))
        percent (Math/floor percent)
        expanded (:expanded @local)]
    [:div.updater
     [:i.fas
      {:class    (if expanded
                   "fa-chevron-double-down"
                   "fa-chevron-double-up")
       :on-click #(swap! local update :expanded not)}]
     (when expanded
       [:h2 "Downloading new meo version."])
     [:div.meter
      [:span {:style {:width (str percent "%")}}]]
     (when expanded
       [:div.info
        [:div [:strong "Total size: "] total " MB"]
        [:div [:strong "Transferred: "] transferred " MB"]
        [:div [:strong "Progress: "] percent "%"]
        [:div [:strong "Speed: "] mbs " MB/s"]])
     (when expanded
       [cancel-btn])]))

(defn update-downloaded []
  (let [install (fn [_]
                  (info "Install button clicked")
                  (emit [:update/install]))]
    [:div.updater
     [:h2 "New version of meo ready to install."]
     [cancel-btn]
     " "
     [:button {:on-click install} "install"]]))

(def test-status
  {:status :update/downloading
   :info   {:total          211111111
            :percent        10.47368
            :bytesPerSecond 22222213
            :transferred    22111121}})

(defn updater
  "Updater view component"
  []
  (let [local (r/atom {})
        updater-status (subscribe [:updater-status])]
    (fn updater-render []
      (let [status-msg @updater-status
            status (:status status-msg)]
        (when (and status
                   (not= :update/closed status))
          [:div.updater
           (case status
             :update/checking [checking]
             :update/not-available [no-update local]
             :update/available [update-available status-msg]
             :update/downloading [downloading status-msg local]
             :update/downloaded [update-downloaded]
             [:div
              [:h2 "meo Updater status: "]
              [:pre [:code (with-out-str (pp/pprint status-msg))]]])])))))
