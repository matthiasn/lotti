(defproject matthiasn/meins "0.0-SNAPSHOT"
  :description "meins - a personal information manager"
  :url "https://github.com/matthiasn/meins"
  :license {:name "GNU AFFERO GENERAL PUBLIC LICENSE"
            :url  "https://www.gnu.org/licenses/agpl-3.0.en.html"}
  :dependencies [[buddy/buddy-sign "3.1.0"]
                 [camel-snake-kebab "0.4.1"]
                 [ch.qos.logback/logback-classic "1.2.3"]
                 [cheshire "5.9.0"]
                 [clj-http "3.10.0"]
                 [clj-pid "0.1.2"]
                 [clj-time "0.15.2"]
                 [clj.qrgen "0.4.0"]
                 [clucy "0.4.0"]
                 [com.climate/claypoole "1.1.4"]
                 [com.drewnoakes/metadata-extractor "2.12.0"]
                 [com.taoensso/nippy "2.14.0"]
                 [com.taoensso/timbre "4.10.0" :exclusions [io.aviso/pretty]]
                 [com.walmartlabs/lacinia "0.32.0"]         ; update to 0.35.0 breaks queries
                 [com.walmartlabs/lacinia-pedestal "0.12.0"]
                 [danlentz/clj-uuid "0.1.9"]
                 [enlive "1.1.6"]
                 [factual/geo "3.0.1"]
                 [hiccup "1.0.5"]
                 [image-resizer "0.1.10"]
                 [markdown-clj "1.10.1"]
                 [matthiasn/systems-toolbox "0.6.41"]
                 [matthiasn/systems-toolbox-sente "0.6.32"]
                 [me.raynes/conch "0.8.0"]
                 [me.raynes/fs "1.4.6"]
                 [metrics-clojure "2.10.0"]
                 [metrics-clojure-jvm "2.10.0"]
                 [org.clojure/clojure "1.10.1"]
                 [org.clojure/core.async "0.7.559"]
                 [org.clojure/data.avl "0.1.0"]
                 [org.clojure/data.csv "0.1.4"]
                 [org.clojure/test.check "0.10.0"]
                 [org.clojure/tools.logging "0.5.0"]
                 [org.clojure/tools.reader "1.3.2"]
                 [org.eclipse.jetty.websocket/websocket-api "9.4.7.v20170914"]
                 [org.eclipse.jetty.websocket/websocket-server "9.4.7.v20170914"]
                 [org.eclipse.jetty/jetty-server "9.4.7.v20170914"]
                 [progrock "0.1.2"]
                 [ring/ring-core "1.8.0"]
                 [ubergraph "0.8.2"]
                 [vincit/venia "0.2.5"]]

  :source-paths ["src/cljc" "src/clj/"]

  :clean-targets ^{:protect false} ["prod/main"
                                    "prod/renderer"
                                    "prod/geocoder"
                                    "prod/updater"
                                    "target"
                                    "out"
                                    "dev/renderer"]
  :auto-clean false
  :uberjar-name "meins.jar"

  :main meins.jvm.core
  :jvm-opts ["-Xmx2g"]

  :profiles {:uberjar {:aot :all}
             :dev     {:source-paths ["src/cljc" "src/clj/" "dev-resources" "dev"]
                       :dependencies [;[io.dgraph/dgraph4j "1.7.1"]
                                      [org.clojure/tools.namespace "0.3.1"]]}}

  :repl-options {:init-ns meins.jvm.core}

  :doo {:paths {:karma "./node_modules/karma/bin/karma"}}

  :plugins [[deraen/lein-sass4clj "0.5.0"]
            [lein-ancient "0.6.15"]
            [lein-jlink "0.2.1"]
            [lein-nsorg "0.3.0"]
            [test2junit "1.4.2"]]

  :jlink-modules ["java.base" "java.sql" "java.desktop" "java.naming"
                  "java.management" "jdk.unsupported" "jdk.crypto.cryptoki"]

  :test2junit-run-ant true

  :sass {:source-paths ["src/scss/"]
         :target-path  "resources/public/css/"})
