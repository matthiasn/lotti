(defproject matthiasn/meo "0.0-SNAPSHOT"
  :description "meo - a personal information manager"
  :url "https://github.com/matthiasn/systems-toolbox"
  :license {:name "GNU AFFERO GENERAL PUBLIC LICENSE"
            :url  "https://www.gnu.org/licenses/agpl-3.0.en.html"}
  :dependencies [[org.clojure/clojure "1.9.0"]
                 [org.clojure/clojurescript "1.9.946"]
                 [org.clojure/tools.logging "0.4.0"]
                 [ch.qos.logback/logback-classic "1.2.3"]
                 [hiccup "1.0.5"]
                 [clj-pid "0.1.2"]
                 [clj-time "0.14.2"]
                 [clj-http "3.7.0"]
                 [enlive "1.1.6"]
                 [me.raynes/fs "1.4.6"]
                 [markdown-clj "1.0.2"]
                 [clj-pdf "2.2.30"]
                 [cheshire "5.8.0"]
                 [me.raynes/conch "0.8.0"]
                 [com.taoensso/nippy "2.14.0" :exclusions [com.taoensso/encore]]
                 [com.taoensso/timbre "4.10.0" :exclusions [io.aviso/pretty]]
                 [cljsjs/moment "2.17.1-1"]
                 [com.drewnoakes/metadata-extractor "2.11.0"]
                 [ubergraph "0.4.0"]
                 [factual/geo "1.2.1"]
                 [camel-snake-kebab "0.4.0"]
                 [matthiasn/systems-toolbox "0.6.32"]
                 [matthiasn/systems-toolbox-kafka "0.6.16"]
                 [matthiasn/systems-toolbox-sente "0.6.21"]
                 [matthiasn/systems-toolbox-electron "0.6.20"]
                 [reagent "0.8.0-alpha2" :exclusions [cljsjs/react cljsjs/react-dom]]
                 [re-frame "0.10.3"]
                 [secretary "1.2.3"]
                 [capacitor "0.6.0"]
                 [clucy "0.4.0"]
                 [seesaw "1.4.5"]
                 [clj.qrgen "0.4.0"]
                 [image-resizer "0.1.10"]
                 [danlentz/clj-uuid "0.1.7"]
                 [org.webjars.bower/fontawesome "4.7.0"]
                 [org.webjars.npm/randomcolor "0.4.4"]
                 [org.webjars.bower/normalize-css "5.0.0"]
                 [org.webjars.bower/leaflet "0.7.7"]
                 [org.webjars.npm/github-com-mrkelly-lato "0.3.0"]
                 [org.webjars.npm/intl "1.2.4"]]

  :source-paths ["src/cljc" "src/clj/"]

  :clean-targets ^{:protect false} ["resources/public/js/build" "prod" "target"
                                    "out" "dev"]
  :auto-clean false
  :uberjar-name "meo.jar"

  :main meo.jvm.core
  :jvm-opts ["-XX:-OmitStackTraceInFastThrow" "-XX:+AggressiveOpts"]

  :profiles {:uberjar      {:aot :all}
             :test-reagent {:dependencies [[cljsjs/react "15.6.1-2"]
                                           [cljsjs/react-dom "15.6.1-2"]
                                           [cljsjs/create-react-class "15.6.0-2"]]}}

  :doo {:paths {:karma "./node_modules/karma/bin/karma"}}

  :plugins [[lein-cljsbuild "1.1.7"
             :exclusions [org.apache.commons/commons-compress]]
            [lein-figwheel "0.5.14"]
            [test2junit "1.3.3"]
            [deraen/lein-sass4clj "0.3.1"]
            [lein-shell "0.5.0"]
            [lein-ancient "0.6.15"]]

  ;:global-vars {*assert* false}

  :test2junit-run-ant true

  :sass {:source-paths ["src/scss/"]
         :target-path  "resources/public/css/"}

  :aliases {"dist" ["do"
                    ["clean"]
                    ["test"]
                    ["cljsbuild" "once" "main"]
                    ["cljsbuild" "once" "renderer"]
                    ["cljsbuild" "once" "geocoder"]
                    ["cljsbuild" "once" "updater"]
                    ["sass4clj" "once"]
                    ["uberjar"]]}

  :cljsbuild {:test-commands {"cljs-test" ["phantomjs" "test/phantom/test.js" "test/phantom/test.html"]}
              :builds        [{:id           "main"
                               :source-paths ["src/cljc" "src/cljs"]
                               :compiler     {:main           meo.electron.main.core
                                              :target         :nodejs
                                              :output-to      "prod/main/main.js"
                                              :output-dir     "out/main"
                                              :optimizations  :simple
                                              :parallel-build true}}

                              {:id           "geocoder"
                               :source-paths ["src/cljc" "src/cljs"]
                               :compiler     {:main           meo.electron.geocoder.core
                                              :target         :nodejs
                                              :output-to      "prod/geocoder/geocoder.js"
                                              :output-dir     "out/geocoder"
                                              :optimizations  :simple
                                              :parallel-build true}}

                              {:id           "renderer"
                               :source-paths ["src/cljc" "src/cljs"]
                               :compiler     {:main           meo.electron.renderer.core
                                              :output-to      "prod/renderer/renderer.js"
                                              :target         :nodejs
                                              :output-dir     "out/renderer"
                                              :optimizations  :simple
                                              :parallel-build true}}
                              {:id           "renderer-dev"
                               :source-paths ["src/cljc" "src/cljs"]
                               :compiler     {:main           meo.electron.renderer.core
                                              :output-to      "dev/renderer/renderer.js"
                                              :output-dir     "dev/renderer"
                                              :source-map     true
                                              :target         :nodejs
                                              :optimizations  :none
                                              :parallel-build true}}

                              {:id           "updater"
                               :source-paths ["src/cljs"]
                               :compiler     {:main           meo.electron.update.core
                                              :output-to      "prod/updater/updater.js"
                                              :output-dir     "out/updater"
                                              :target         :nodejs
                                              :optimizations  :simple
                                              :parallel-build true}}

                              {:id           "cljs-test"
                               :source-paths ["src/cljs" "src/cljc" "test"]
                               :compiler     {:output-to     "out/testable.js"
                                              :output-dir    "out/"
                                              :main          meo.jvm.runner
                                              :process-shim  false
                                              :optimizations :whitespace}}]})
