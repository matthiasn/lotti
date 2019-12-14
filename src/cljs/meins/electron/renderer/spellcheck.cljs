(ns meins.electron.renderer.spellcheck
  (:require #_[electron-spellchecker
             :refer [SpellCheckHandler ContextMenuListener ContextMenuBuilder]]
            [taoensso.timbre :refer [info]]))

(defn set-lang [{:keys [msg-payload current-state]}]
  (let [cc msg-payload
        _spellcheck-handler (:spellcheck-handler current-state)]
    (info "Setting SpellChecker language:" cc)
    ;(.switchLanguage spellcheck-handler cc)
    {}))

#_
(defn state-fn [_put-fn]
  (let [spellcheck-handler (SpellCheckHandler.)
        cm-builder (ContextMenuBuilder. spellcheck-handler)]
    (ContextMenuListener. #(.showPopupMenu cm-builder %))
    (aset js/window "spellCheckHandler" spellcheck-handler)
    (.attachToInput spellcheck-handler)
    (info "SpellCheckhandler started in auto mode")
    {:state (atom {:spellcheck-handler spellcheck-handler})}))

(defn spellcheck-off [{:keys []}]
  (info "SpellChecker OFF")
  (aset js/window "spellCheckHandler" "currentSpellchecker" nil)
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   ;:state-fn    state-fn
   :handler-map {:spellcheck/lang set-lang
                 :spellcheck/off  spellcheck-off}})
