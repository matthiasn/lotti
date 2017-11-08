(ns meo.electron.renderer.spellcheck
  (:require [electron-spellchecker
             :refer [SpellCheckHandler ContextMenuListener ContextMenuBuilder]]
            [taoensso.timbre :as timbre :refer-macros [info]]))

(defn set-lang [{:keys [msg-payload]}]
  (let [cc msg-payload
        spellcheck-handler (SpellCheckHandler.)
        cm-builder (ContextMenuBuilder. spellcheck-handler)
        cm-listener (ContextMenuListener. #(.showPopupMenu cm-builder %))]
    (info "Setting SpellChecker language:" cc)
    (aset js/window "spellCheckHandler" spellcheck-handler)
    (.attachToInput spellcheck-handler)
    (.switchLanguage spellcheck-handler cc)
    {}))

(defn state-fn [put-fn]
  (set-lang {:msg-payload "en-US"})
  {:state (atom {})})

(defn spellcheck-off [{:keys []}]
  (info "SpellChecker OFF")
  (aset js/window "spellCheckHandler" "currentSpellchecker" nil)
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:spellcheck/lang set-lang
                 :spellcheck/off  spellcheck-off}})
