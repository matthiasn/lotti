(ns meins.ui.settings.audio
  (:require ["@matthiasn/react-native-audio-recorder-player" :default rn-audio-recorder-player]
            ["react-native-permissions" :as Permissions]
            [cljs-bean.core :refer [->clj ->js bean]]
            [matthiasn.systems-toolbox.component :as st]
            [meins.helpers :as h]
            [meins.ui.db :refer [emit]]
            [meins.ui.settings.items :refer [button item settings-page settings-text]]
            [meins.ui.shared :refer [alert platform-os settings-icon
                                     status-bar text view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [taoensso.timbre :refer-macros [debug error info]]))

(def perm (aget Permissions "default"))

(defn audio-settings [_]
  (let [player-state (r/atom {:status :paused
                              :pos    0})
        recorder-player (rn-audio-recorder-player.)]
    (-> (.request perm "microphone" (clj->js {}))
        (.then #(js/console.info "permission granted")))
    (fn [{:keys [navigation] :as _props}]
      (let [{:keys [_navigate _goBack]} navigation
            record-cb (fn [e]
                        (let [pos (.-current_position e)
                              ev (->clj e)]
                          (info ev)
                          (swap! player-state assoc-in [:pos] pos)
                          (swap! player-state assoc-in [:dur] pos)))
            record (fn [_]
                     (let [dir (when (= "android" platform-os)
                                 "/data/data/com.matthiasn.meins/")
                           file (str (st/now) ".m4a")
                           path (str dir file)
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
            status (:status @player-state)
            pos (h/mm-ss (.floor js/Math (:pos @player-state)))
            dur (h/mm-ss (.floor js/Math (:dur @player-state)))
            file (:file @player-state)]
        [settings-page
         (if (= :rec status)
           [item {:label    "Stop Recording"
                  :icon     (settings-icon "stop" "#F66")
                  :on-press stop-recording}]
           [item {:label    "Record"
                  :icon     (settings-icon "microphone" "#999")
                  :on-press record}])
         (if (= :play status)
           [item {:label    "Stop"
                  :icon     (settings-icon "stop" "#66F")
                  :on-press stop}]
           [item {:label    "Play"
                  :icon     (settings-icon "play" "#999")
                  :on-press play}])
         (when (and file (= :paused status))
           [item {:label    "Save"
                  :icon     (settings-icon "save" "#66F")
                  :on-press save}])
         (when file
           [text {:style {:font-size   32
                          :color       "#888"
                          :font-weight "100"
                          :font-family "Courier"
                          :margin      20}}
            pos "/" dur])]))))
