(ns meins.ui.settings.audio
  (:require [meins.ui.colors :as c]
            [meins.ui.shared :refer [view text settings-list settings-list-item settings-icon
                                     rn-audio-recorder-player alert status-bar platform-os]]
            [re-frame.core :refer [subscribe]]
            ["react-native-permissions" :as Permissions]
            [reagent.core :as r]
            [meins.helpers :as h]
            [meins.ui.db :refer [emit]]
            [matthiasn.systems-toolbox.component :as st]))

(def perm (aget Permissions "default"))

(defn audio-settings [_]
  (let [theme (subscribe [:active-theme])
        player-state (r/atom {:status :paused
                              :pos    0})
        recorder-player (rn-audio-recorder-player.)]
    (-> (.request perm "microphone" (clj->js {}))
        (.then #(js/console.info "permission granted")))
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            record-cb (fn [e]
                        (let [pos (.-current_position e)]
                          (swap! player-state assoc-in [:pos] pos)
                          (swap! player-state assoc-in [:dur] pos)))
            record (fn [_]
                     (let [prefix (when (= "android" platform-os)
                                    "/data/data/com.matthiasn.meins/")
                           file (str (st/now) ".m4a")
                           path (str prefix file)
                           uri-promise (.startRecorder recorder-player path)]
                       (.then uri-promise #(js/console.log %))
                       (swap! player-state assoc-in [:status] :rec)
                       (swap! player-state assoc-in [:file] file)
                       (.addRecordBackListener recorder-player record-cb)))
            stop-recording (fn [_]
                             (let [stop-promise (.stopRecorder recorder-player)]
                               (.then stop-promise #(js/console.log %))
                               (.removeRecordBackListener recorder-player)
                               (swap! player-state assoc-in [:status] :paused)))
            play (fn [_]
                   (.startPlayer recorder-player (:file @player-state))
                   (.addPlayBackListener
                     recorder-player
                     #(swap! player-state assoc-in [:pos] (.-current_position %)))
                   (swap! player-state assoc-in [:status] :play))
            stop (fn [_]
                   (.stopPlayer recorder-player)
                   (.removePlayBackListener recorder-player)
                   (swap! player-state assoc-in [:status] :paused))
            save (fn [_]
                   (let [entry {:md         (h/mm-ss (.floor js/Math (:dur @player-state)))
                                :perm_tags  #{"#audio"}
                                :audio_file (:file @player-state)}]
                     (h/new-entry-fn emit entry)
                     (reset! player-state {:pos 0 :status :paused})))
            bg (get-in c/colors [:list-bg @theme])
            item-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])
            status (:status @player-state)
            pos (h/mm-ss (.floor js/Math (:pos @player-state)))
            dur (h/mm-ss (.floor js/Math (:dur @player-state)))
            file (:file @player-state)]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :background-color bg
                       :height           "100%"}}
         [status-bar {:barStyle "light-content"}]
         [settings-list {:border-color bg
                         :width        "100%"}
          (if (= :rec status)
            [settings-list-item {:title            "Stop Recording"
                                 :hasNavArrow      false
                                 :background-color item-bg
                                 :titleStyle       {:color text-color}
                                 :icon             (settings-icon "stop" "#F66")
                                 :on-press         stop-recording}]
            [settings-list-item {:title            "Record"
                                 :hasNavArrow      false
                                 :background-color item-bg
                                 :titleStyle       {:color text-color}
                                 :icon             (settings-icon "microphone" "#999")
                                 :on-press         record}])
          (if (= :play status)
            [settings-list-item {:title            "Stop"
                                 :hasNavArrow      false
                                 :background-color item-bg
                                 :titleStyle       {:color text-color}
                                 :icon             (settings-icon "stop" "#66F")
                                 :on-press         stop}]
            [settings-list-item {:title            "Play"
                                 :hasNavArrow      false
                                 :background-color item-bg
                                 :titleStyle       {:color text-color}
                                 :icon             (settings-icon "play" "#999")
                                 :on-press         play}])
          (when (and file (= :paused status))
            [settings-list-item {:title            "Save"
                                 :hasNavArrow      false
                                 :background-color item-bg
                                 :titleStyle       {:color text-color}
                                 :icon             (settings-icon "save" "#66F")
                                 :on-press         save}])
          (when file
            [text {:style {:font-size   32
                           :color       "#888"
                           :font-weight "100"
                           :font-family "Courier"
                           :margin      20}}
             pos "/" dur])]]))))
