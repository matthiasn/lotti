# Lotti's Manual

Lotti is a digital assistant that allows you to answer questions about your life by chatting with
your data, for example by asking what you learned regarding a certain category (such as work) in the
2nd quarter of 2025 (already implemented) and it will also at some point allow answering questions
about a broader set of data, such as from Apple Health and how you're tracking towards goals you
might have. Lotti then lets you utilize AI to interact with your data, and gives you fine-grained
control over which data you share with which inference provider. It also lets you run all of its
functionality locally using open weights models, and thus not sharing any data with anyone at all,
with the best available models requiring very powerful hardware though. You can use anything that
Ollama allows you to run. In addition, Lotti comes with locally running Python services for speech
recognition. For that, there are currently two options, either using Whisper or using Gemma 3n.

The main building blocks for the current functionality of chatting with a particular category are
tasks, audio recordings, capturing screenshots, checklists, and time tracking. We will look into
each of those here, but first let's look at the basic setup. You will most certainly need some
categories to use Lotti, so let's start with those, and then get the AI interactions set up.

## Categories

Categories are different important aspects of your life. Examples (in no particular order):

- Health
- Sleep
- Physical Fitness
- Mindfulness
- Family
- Social Life
- Creative Expression
- Dental Health
- Money
- Work
- ...

Lotti lets you define those different categories, and then assign them to other entities, such 
as tasks, habits, and dashboards. Categories can then be used for example for filtering by 
categories, and be able to focus on one (or a few) at a time. Categories then also allow you to 
define with AI prompts are available in that category, and which will be run automatically if so 
desired.

### Create Categories

In `Settings > Categories`, you can add and manage categories used elsewhere in the app. Initially,
you will see an empty page:

![Category Settings - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/categories_empty.png)

Tap the plus icon at the bottom right to create a new category, and enter the name and hex color as
desired, for example:

![Health Category](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/category_health.png)

You can also use a color picker to get exactly the color that means something to you. For that, tap
the color palette on the right side of the hex color field and pick what you like:

![Health Category - Color Picker](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/category_health_picker.png)

Finally, tap the save button. Repeat until you have a good idea what areas you want to look at next
(you can always add more categories later). For example:

![Category Settings](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/categories.png)

## AI integration

The AI integration consists of three parts:

- Inference providers: for example Ollama running locally, or also Google Gemini, OpenAI's ChatGPT
  models, Anthropics's Claude, or anything that provides an OpenAI-compatible API
- Models: Here you define which models will be available for inference for a given provider to use
  in your prompts. The goal is to come with sensible defaults for each. Please don't hesitate to
  open pull requests for anything that's missing. You can also create custom models anytime, so no
  pull request is required to use a model that's not known to the application yet.
- Prompts: there are predefined prompts that are used in different places in the app, such as a
  prompt for summarizing tasks. You can edit prompts as you see fit, or you can decide to track
  prompts from the project repository, which means those get updated automatically to benefit from
  potential improvements (default). Editing is only possible after disabling tracking the upstream
  prompt, so you're effectively doing a fork here. We will go into more details about the different
  prompt types below.

### Providers

The simplest option here is Ollama. Make sure to have it installed and running locally, then go to
`Settings > AI Settings > Providers` and click *Add Provider`, then select provider type Ollama. 
For a default installation of Ollama on your local machine, you won't have to do anything else. 
Press save and you're good to go. Then go to `Models`, you will notice that some default models were
added automatically. Feel free to clean up the ones you won't need. Just note that currently, once
deleted you will have to set up the same model again manually, or delete the provider, which will
automatically delete all the related models in a cascade. There's no other way to get the predefined
models back at the moment. Please open an issue if you feel like model management should be
smoother, e.g. with a la carte adding of known models to a provider.

### Models

Models have a bunch of configurable options, such as the provider that is used for a model, as
display name (can be whatever you like), the model ID as known by the provider, an optional
description, an optional number of completion tokens, and then the model's capabilities, such as the
input modalities, where text, image, and audio are supported. Obviously the model will have to
support what you select. There is a field for output modalities here as well, but here at the moment
only text is supported for output.

Then finally you can select if the model supports reasoning and function calling. The predefined
models that are created when creating a provider with known predefined models come correctly
configured. Additional model parameters such as temperature did not appear all that useful so 
far, but feel free to open issues for additional parameters, or better yet, submit a pull 
request with the field you're missing

### Prompts

Prompts are where it gets interesting. 


### AI config by category

By default, for no AI inference at all is enabled for any newly created category. This is by 
design so you cannot accidentally share data with cloud providers. Prompt MUST EXPLICITLY be 
enabled per category.

ADD SCREENSHOTS AND DESCRIBE


### Automated Speech Recognition (ASR)

#### Gemini Flash or Gemini Pro

There are different options for speech recognition, with Google's Gemini offering the best overall
quality, especially when used with the task context prompt. This prompt gives the model the 
whole task context, as in the text of all entries, plus the checklist items. This allows the 
speech recognition to be much better with names that are already used in the task, as compared 
to plain speech recognition with zero additional context. But of course this has the same 
privacy implications as anything cloud based, so it's a tradeoff. You can either use Gemini Flsh 
or Gemini Pro here, where Flash has proven to be an excellent (and much cheaper) choice.

Then there is a locally running Whisper service. You would have to check out the repository and 
run it locally, then this service will install the model on first run, and listen to a local 
port and provide pretty decent transcription quality. However, Whisper is not able to take the 
entire task context into account, so it won't be anywhere near as good as the Gemini models 
especially with names.

#### Whisper (locally)

To run the Whisper service, please refer to the respective [README](../whisper_server/README.md).
Once it is running, add whisper as a provider and set up a transcription prompt to use it in the 
app. Please note that, for the same reason as why the context won't be respected, it also 
doesn't matter how you edit the prompt, the Whisper service will not honor it but just provide a 
transcript the best way it can.

ADD SCREENSHOTS AND DESCRIBE

#### Gemma 3N (locally)

Similar to the Whisper service, there's also an implementation of a service running Google's 
latest open-weights multimodal Gemma 3N models. Please refer to the respective [README](.. 
/services/gemma-local/README.md) for how to set it up Whisper service.

ADD SCREENSHOTS AND DESCRIBE

Gemma is a full LLM that will take into account the task context. It's a more recent addition to 
the project and is much less battle tested than the Whisper service. Please keep that in mind
and raise issues for anything unexpected that you encounter.

## Additional data types

**Implementation is currently a bit outdated, there will be more focus on this in the future, for
now the main focus is the task tracking**

Lotti lets you track more data about your life, such as measurement and habit completions.
Measurements could, for example, include tracking exercises, plus imported data from Apple Health or
the equivalent on Android. As far as habits got, that could be the intake of medication, numbers of
repetitions of an exercise, the amount of water you drink, the amount of fiber you ingest, you name
it. Anything you can imagine. If you create a habit, you can assign any dashboard you want, and then
by the time you want to complete a habit, look at the data and determine at a quick glance of the
conditions are indeed met for successful completion.

## Habits

### Create Habits

Now that categories are defined, let's add some habits. Technically, you could add habits without
categories, but then those habits would be displayed with a boring gray color, and that would look
pretty boring. Got to `Settings > Habits`:

![Habit Settings - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habits_empty.png)

Tap the plus icon and add a title:

![New Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit3_initial.png)

Here, you can also assign the category you created earlier, in this case `Fitness`:

![New Habit - Select Category](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit3_category.png)

Finally, save the habit:

![New Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit3_final.png)

Repeat creating habits until all the ones you want to start with are defined, for example:

![New Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habits.png)

### Complete Habits on a regular base

Go to the Habits page, all the way to the left (this page is also shown after application startup).
This could initially look like this:

![Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit_completions1.png)

Above, you'll notice that the habit completion chart is all red. You can remedy this in one of two
ways:

- Backfilling by adding habit completions for previous days.
- Defining the start date in the settings of a habit.

#### Habit completion backfill (optional)

You can backfill habit completions for previous days by tapping on the previous days in the row
below the habit titles, which will create a habit completion entry at `23:59` of that particular
day. For example, when you know walked at least 10K steps two days ago but were lazy yesterday, tap
the red rounded rectangle two from the right and complete the habit as a 'success', and the same for
one further to the right, but completed as a 'fail', and so on:

![Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit_completion_10k_steps.png)

Eventually, you will end up with a habit completion card that might look a lot more satisfying than
the all red indicator row in the beginning:

![Habit - 10k+ Steps backfilled](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit_completion_10k_all.png)

#### Habit completion

Whenever you want to complete a habit, e.g. because you just flossed, took a certain medication, or
whatever else the desired recurring behavior might be, you just tap the checkmark icon on the far
right of a habit completion card. A dialog will open for completing the habit, with date and time
prefilled, where you can complete a habit with one of three habit completion types:

- **Fail**: I record this state when I could have done something but failed to do so. Example: I
  could’ve flossed but did not.
- **Skip**: this state is meant for habits where I was motivated to complete a habit but could not,
  for reasons outside of my responsibility. Example: let’s say I want to play ping pong every day
  but if I don’t find anyone to play with, I use skip. I also use skip for habits that I only want
  to complete once or a few times for week. Could be a weekly fluoride treatment for stronger teeth,
  or running, where I only record fail if the last time is too long ago. But if I went running
  yesterday, it’s a skip as I don’t even want to go running every day.
- **Success**: this is obviously the desired state. I’m aiming for checking off 80% or more of my
  habits every day, hence also the 80% line in the chart.

![Habit - 10k+ Steps now](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit_completion_10k_steps_now.png)

The Habits page has different section for habits that are open now, habits due later, and habits
that were already completed for the day. Example for the latter:

![Habits - done](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit_completions_done.png)

The habit completion dialog can also show data relevant to the respective habit, for example the
different exercise types related for example to a `morning exercises` habit. But first, we need to
look at defining measurable data types and dashboards.

## Creating Measurables

Measurable data types are managed in `Settings > Measurable Data Types`:

![Measurable Data Types - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/measurables_empty.png)

You can add new measurable data types with the **+** icon on the Measurables page, and existing ones
can be searched and edited:

![Measurable Data Type - Pull-ups](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/measurable_pull_ups.png)

The name needs to be filled out, description and unit type are optional. There are different
aggregation types (also optional):

- **None:** will result in a line chart with each value representing a point on the line at
  measurement. Useful, for example, for body measurements, number of followers, balances, etc.
- **Daily Sum:** will result in a bar chart with all measurements added per day. Useful, for
  example, for repetitions of exercises. This is the default when nothing is selected.
- **Daily Max:** will result in a bar chart with the maximum value for a day, one per day (not
  currently implemented).
- **Daily Average:** will result in a bar chart with the maximum value for a day, one per day (not
  currently implemented).

Press save when completed. You will get back to the list of measurable data types, for example:

![Measurable Data Types](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/measurables.png)

## Creating Dashboards

Dashboards are managed in `Settings > Dashboard Management`:

![Dashboards - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/dashboards_empty.png)

Here, you can either search and then edit existing dashboards, or create new ones with the **+**
icon. Add a name, plus an optional description:

![Dashboard - Exercises](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/dashboard_exercise.png)

Next, select one or more `Measurable Data Chart` items, followed by tapping `OK`:

![Dashboard - Exercises](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/dashboard_exercise2.png)

Finally, save the dashboard.

![Dashboard - Exercises](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/dashboard_exercise3.png)

![Dashboards - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/dashboards.png)

You can add any number of measurable types in a dashboard, and reorder the charts as desired. Health
data types will be imported first time you open the dashboard.

Finally, you can view the dashboard in the dashboards tab:

![Dashboards - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/dashboards_tab.png)

## Screenshots (Desktop-only) [OUTDATED]

You can use Lotti to capture screenshots, for example when documenting tasks. You can create
screenshots on the journal page using the **+** button and then selecting this icon:

![Exercises dashboard screenshot](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/journal_add_screenshot.png)

It would be useful to also be able to create screenshots from the app menu,
see [#1011](https://github.com/matthiasn/lotti/issues/1011) - help is very welcome.

## Audio Recordings

## Questionnaires

## Tasks

