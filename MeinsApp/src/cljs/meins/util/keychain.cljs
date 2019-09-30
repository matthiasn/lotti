(ns meins.util.keychain
  (:require ["react-native-keychain" :as kc :refer [getGenericPassword resetGenericPassword setGenericPassword]]
            [cljs.tools.reader.edn :as edn]))

(defn get-keypair
  "Gets keypair from keychain and invokes callback with the result as a map."
  [cb]
  (-> (getGenericPassword)
      (.then (fn [res]
               (try
                 (let [secret (.-password res)
                       parsed (edn/read-string secret)]
                   (cb parsed))
                 (catch :default e (js/console.error "get-keypair" e)))))
      (.catch (fn [e] (js/console.error e)))))

(defn set-keypair
  "Sets keypair in keychain."
  [kp]
  (-> (setGenericPassword "meins" (pr-str kp))
      (.then (fn [res]
               (js/console.warn "setGenericPassword" res)
               (get-keypair #(js/console.warn "publicKey" (:publicKey %)))))
      (.catch (fn [e] (js/console.error e)))))

(defn del-keypair
  "Deletes keypair from keychain."
  []
  (-> (resetGenericPassword "meins")
      (.then (fn [res]
               (js/console.warn "resetGenericPassword" res)
               (get-keypair #(js/console.warn "publicKey" (:publicKey %)))))
      (.catch (fn [e] (js/console.error e)))))
