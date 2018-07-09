(ns meo.electron.renderer.ui.entry.wavesurfer
  (:require [wavesurfer.js :as wavesurfer]
            [taoensso.timbre :refer-macros [info debug]]
            [reagent.core :as r]
            [meo.electron.renderer.helpers :as h]))

(def iww-host (.-iwwHOST js/window))
(def intersection-observer (aget js/window "IntersectionObserver"))

(defn wavesurfer-did-mount [props]
  (fn []
    (let [{:keys [audio-file id ts local]} props
          dom-id (str "#" id)
          waveform (.create wavesurfer (clj->js {:container     dom-id
                                                 :waveColor     "#FFDE99"
                                                 :height        80
                                                 :normalize     true
                                                 :cursorWidth   2
                                                 :progressColor "#FF5F1A"}))
          url (str "http://" iww-host "/audio/" audio-file)
          progress (fn [p]
                     (swap! local assoc-in [:progress] p)
                     (.setItem js/localStorage ts p))
          elem (.querySelector js/document dom-id)
          stop-on-hide #(when (zero? (aget % 0 "intersectionRatio")) (.stop waveform))
          io (intersection-observer. stop-on-hide (clj->js {}))]
      (.observe io elem)
      (.load waveform url)
      (.on waveform "ready" (fn []
                              (let [dur (.getDuration waveform)
                                    progress (.getItem js/localStorage ts)]
                                (info :ready progress)
                                (when progress (.skip waveform progress))
                                (swap! local assoc-in [:duration] dur))))
      (.on waveform "audioprocess" progress)
      (.on waveform "play" #(swap! local assoc-in [:status] :playing))
      (.on waveform "pause" #(swap! local assoc-in [:status] :paused))
      (.on waveform "finish" #(swap! local assoc-in [:status] :finished))
      (swap! local assoc-in [:waveform] waveform))))

(defn wavesurfer-cmp [props]
  (r/create-class
    {:component-did-mount (wavesurfer-did-mount props)
     :reagent-render      (fn [props]
                            (let [{:keys [local skip-fwd skip-back play-pause]} props
                                  progress (or (:progress @local) 0)
                                  progress (h/s-to-mm-ss-ms
                                             (int (* 1000 progress)))
                                  duration (or (:duration @local) 0)
                                  duration (h/s-to-mm-ss-ms
                                             (int (* 1000 duration)))
                                  stop #(.stop (:waveform @local))
                                  zoom (fn [ev]
                                         (let [v (.. ev -target -value)
                                               v (when (seq v) (js/parseFloat v))]
                                           (swap! local assoc-in [:zoom] v)
                                           (.zoom (:waveform @local) v)))]
                              [:div.wavesurfer
                               [:div {:id (:id props)}]
                               [:div.controls
                                [:span.ctrl-btn {:on-click skip-back}
                                 [:i.fas.fa-step-backward]]
                                [:span.ctrl-btn {:on-click play-pause}
                                 (if (= :playing (:status @local))
                                   [:i.fas.fa-pause]
                                   [:i.fas.fa-play])]
                                [:span.ctrl-btn {:on-click stop}
                                 [:i.fas.fa-stop]]
                                [:span.ctrl-btn {:on-click skip-fwd}
                                 [:i.fas.fa-step-forward]]
                                [:span.time
                                 [:span.progress progress]
                                 "/"
                                 [:span.duration duration]]
                                [:input {:on-input zoom
                                         :type     :range
                                         :min      1
                                         :max      100
                                         :value    (:zoom @local)}]]]))}))

(defn wavesurfer [entry local-cfg put-fn]
  (when-let [audio-file (:audio_file entry)]
    (let [id (str "wavesurfer" (hash (:vclock entry))
                  (when-let [tab-grp (:tab-group local-cfg)] (name tab-grp)))
          local (r/atom {:zoom 1})
          get-waveform #(:waveform @local)
          play-pause #(.playPause (get-waveform))
          skip-fwd #(.skipForward (get-waveform))
          skip-back #(.skipBackward (get-waveform))
          keydown (fn [ev]
                    (let [key-code (.. ev -keyCode)
                          meta-key (.-metaKey ev)]
                      (debug key-code meta-key)
                      (when (= key-code 32) (play-pause))
                      (when (= key-code 37) (skip-back))
                      (when (= key-code 39) (skip-fwd))
                      (.stopPropagation ev)))
          start-watch #(.addEventListener js/document "keydown" keydown)
          stop-watch #(.removeEventListener js/document "keydown" keydown)]
      [:div {:on-mouse-enter start-watch
             :on-mouse-over  start-watch
             :on-mouse-leave stop-watch}
       [wavesurfer-cmp {:id         id
                        :audio-file audio-file
                        :local      local
                        :ts         (:timestamp entry)
                        :skip-fwd   skip-fwd
                        :skip-back  skip-back
                        :play-pause play-pause
                        :put-fn     put-fn}]])))
