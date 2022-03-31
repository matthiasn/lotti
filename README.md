# Meins/Lotti

This repository contains two related projects,
**[Meins](https://github.com/matthiasn/meins/tree/main/meins/README.md)** and
**[Lotti](https://github.com/matthiasn/meins/tree/main/lotti/README.md)**.

**[Meins](https://github.com/matthiasn/meins/tree/main/meins/README.md)**
started out as a journaling application, with a focus on recording
arbitrary measurable data (such as exercise repetitions, intake of water,
alcohol, medications) in combination with mood and imported health data. The
desktop application is written in **Clojure** and **ClojureScript** using
**Electron** to target all the relevant desktop platforms **Linux**, **Mac**,
and **Windows**. There used to be a mobile companion app for importing 
health data, photos, and audio recordings on the phone. 
This was also written in ClojureScript, using **React Native** to target both **iOS** and **Android**. 
This companion mobile app has been deprecated for a while in favor of a rewrite
in **Flutter**, since there were too many issues with the approach.

**[Lotti](https://github.com/matthiasn/meins/tree/main/lotti/README.md)** is 
more or less an ongoing rewrite of the aforementioned
**Clojure** and **ClojureScript** project, using **Flutter**.
The main reason behind this migration, at least at the beginning, was Flutter's promise to allow building for all screens with a single codebase.
This project is however not a one-for-one migration, since the project aims
have evolved since. It is more and more becoming a toolkit for designing interventions, and thus proactively
creating a better life to look back on, as opposed to just recording what is.
Such interventions could for example be losing weight, improve blood pressure to
prevent cardiovascular disease, and anything else you would want to change, and
then monitor success.

Both applications share one important goal: keep private data private. 
Therefore, sync between devices is encrypted and takes place entirely within 
user-provided infrastructure in the form of an IMAP folder. Thus, it is not 
required to share sensitive information (e.g. medical) with anyone.

Come back soon for links to blog posts detailing the reasoning behind the
ongoing migration, and about creating a better, healthier life for yourself by 
creating and monitoring interventions.
