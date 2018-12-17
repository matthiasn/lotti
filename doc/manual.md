# Manual

**Meo** is a data-driven journal that helps you **get your life in order**. First, you define what you want to capture, e.g. how long you sleep, how many steps you take, how much beer you drink. Variables you have some influence on. Then you define habits, where a set of rules determines habit success (or failure). Then you record the data or have meo recorded it for you. A dashboard finally shows you where you succeed and where you fail. Your only job then is to keep everything green, for as long as you possibly can. **Don’t break the chain**, pretty much. Here’s my example of recent success and failure for some of the habits I defined for myself:

![screenshot](./images/20181217_2238_habits.png) 

The dots are only fully saturated after the habit was defined. For some, like steps, I have data far back further, imported on the mobile app.

The habits, together with text notes and photos, and time spent, become the journal of your life. After all, you are in large part what you, and you can capture that in meo, with a timer that you keep running while working on anything. 

In addition, I reserve say fifteen minutes a day for some text about how I am doing and how things are going. I created a habit to monitor that, see the second last line above. Maybe not surprisingly, compliance has gone up substantially after I put this dashboard in plain view, and that’s my general experience. The habits work by far best when I’m forced to look at them, and meo happily does that.

## The Privacy of Your Data

Some of the data I record in meo is not private, in the sense that I would not mind if anyone saw those entries (such as those in the screenshots here). But there are also those where I decidedly would mind if anyone saw them. So why would share these if I did not have to? I believe that everybody should be able to gather data about their lives themselves – without having to donate said data to Silicon Valley, or anyone else. 

With meo, it is very simple. Your data stays with you. Meo does not share of any of your data with anyone. Meo might at some point give you a way to actively share data with others, but there will not ever be any sharing of anything with anyone without your consent, and only ever at your explicit command. That’s all. No fine print, and you can verify all this in the source code. You have no reason to trust anyone’s word when it comes to your private data.


## High-level concepts
Let’s look at the core concepts first, before looking into each of them in detail. The main view of the application currently looks like this:
 
![screenshot](./images/20181217_2250_overview.png) 

On the far left, the is a calendar view shows recorded time. Most of the time is manually recorded, as in, a timer running while completing a task, or recording something that already happened with the #duration tag. However, there is Apple Health integration, which allows the meo app to read this data, and import for example sleep duration and the number of steps and stairs per day, or also blood pressure and pulse. This mobile app is not quite ready for beta testing, please reach out though if you can help in one way or another. The are many different things to do, including helping me get this React Native application work on Android as well. 

The next column right shows an infinitely scrolling calendar where you can select the current day. Below that is a list of habits I committed to and that are still open for today. Each of them shows the success for the past 5 days including today and disappears once successfully completed for the day. 

At the top of the application window, the success of the habits is shown in a different way, giving me a reason to celebrate as more and more of the squares become green.

In the next column, which is the briefing for the day, a list of tasks that are in progress is shown. Here, I can highly recommend limiting work in progress to anywhere between five and ten tasks and not more. More about that later.

Below, there are tasks that are linked with the selected day. These can either be open or finished or rejected. In-progress tasks do not appear here, as they are already shown directly above. Below that is a searchable list for all your open tasks. The next two columns show the result of journal entry searches and showing them in a timeline view with the newest one on top, as we have become accustomed to from social media. If no such view is there, you can add a tab pressing the large “add tab” button. Here, you can search for hashtags and mentions, like this:

[search field view]
Also, you can add a story to the search using $ before starting to type a substring match from the story name. You can also select a date range if you want to narrow down the results.

[The full-text search is currently broken, see this issue. Please help if you can.]

Below briefing and entry timeline view, there is the dashboard. One way I think of it is a banner ad for information about myself that, insofar as the right information is chosen, helps me improve something in my life. Then, since I came back often to track progress on my tasks or take notes of one kind or another, I see this and, even if subconsciously, might do something I said I would, like do my push-ups or whatnot. I found that these banner ads about myself have a better impact on my life than those I otherwise see…




### Entry
Think of it as the logbook of a ship. Only replace the ship with yourself. When available, an entry will have your geolocation and associated time zone, the capture time, and whatever you capture as text (or audio on mobile). Entries can have attached photos and audio files. They can also capture numeric data and durations in custom fields. Custom fields are linked to a hashtag, and the data capture section becomes visible after using the respective hashtag in an entry:
 

There’s also a map section. Also, photos can be imported as entries, and linked to entries as well. Here’s an example:

[TODO: something with running]


At the top left of an entry, you can assign a story. A story can be an ongoing thing, for examplea health-related issue such as weight control, or something that has a clear end, such as a vacation. I will explain the details later.



### Custom Field config
These entries define the custom fields for any particular hashtag. In most cases, you will probably want a single field, such as when capturing the amount of coffee consumed, or the number of hours you slept. You can define custom fields in the preferences. On a Mac, you find the preferences in the application menu under meo > preferences > Custom Fields, and on Linux and Windows, under application > preferences > Custom Fields.

 


Here, you can select an existing custom fields definition entry, optionally filtered by what you put in the search bar, or you can create a new definition. The first thing you need is a hashtag, such as #steps. Tags must consist of that sign a hashtag begins with (hash sign, pound sign, octothorpe, whatever) in the beginning, followed by any number of characters, numbers, underscores, and dashes. This tag, when used in a journal entry, opens a small data capture section at the bottom of an entry, with one label plus capture field per line.

In the case of #steps, all we need is a single field for the number of fields that were recorded on a given day. However, you can define multiple fields, such as the systolic and the diastolic blood pressure for the #BP tag (blood pressure), or duration, distance, altitude gain, and a number of sprints for #running, or whatever else you might find interesting, it’s up to you.

Fields must have a name, which can consist of characters, digits, underscores, and dashes, without blank spaces. As a matter of habit, I typically use 'cnt' here for something that is countable, 'dose' for some medication and vol for the volume of some liquid such as beer. You can use whatever you like the, and meo will present you the existing fields in the habits definition. Then, there is the field type. The available types are number, time, and text. When choosing 'number', you need to select the aggregation. Let me give you an example. When you record four glasses of beer, with 500ml each, you want a result of 2000ml for that given day. This is  'daily sum'. This aggregation is not useful for steps though. Say that during the day, you record multiple times what your current step count is. Now, next time you check, the previously recorded number is already included in the latest count and adding all give you results that are wildly off. Instead, you want max to give you the highest number.

See also the detail section for a detailed explanation of how to define or edit these definition entries.


### Habit
A Habit defines a set of rules or success criteria that unambiguously let meo determine if you’ve either succeeded or failed in achieving something you said you would do. Sounds more complicated than it is. Here are some examples from my life:
•    10K #steps per day: if I manage to walk more than 10,000 steps per day, this is green, otherwise it is red
•    Morning exercises: all of 70 #sit-ups, 20 #push-ups, 30 #lunges, 70s #plank – or else it’s red
•    Drink 2L of #water: if the recorded amount is reached, green, otherwise red

… 


### Dashboard

Above, you saw a dashboard with some of my habits. However, dashboards are more versatile than just habits. Also, the can display information about logged data from custom fields, your blood pressure as a variation on that, and the result of questionnaires.


![screenshot](./images/20181217_2302_dashboard.png)


### Saga
A saga is an overarching kind of story. Stories can belong to a saga, but this is not mandatory.


### Story
Think of a story as something that has its own timeline. Stories get their own colors, and everything in one story will have the same color, for example in the tabs in the journal, or in the calendar when time is logged. Also, the tabs get grouped together by story.



### Private mode
There is plenty of stuff in my journal that I would not freely share with colleagues, friends, and family. I do however need to be able to open meo when other people are around. For this, there is the private mode. This ensures that once activating the little detective button at the top. Then, all the entities described above that do have a private mode switch will be hidden as desired and made safe for work, if you will.
