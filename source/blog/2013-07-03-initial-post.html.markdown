---
title: The Rogue Codewright
---

I've wanted to get a blog going for awhile. Every so often (more so recently), I have an idea or
solve a technical problem and wish I had somewhere to put it. These are mostly incredibly specific
to my own projects, and I don't want to forget how I solved a particular problem when I run
into it again.

So, here we are. I might write about some personal stuff, I will definitely write about technical
stuff. If I do end up including non-technical stuff, I'll at least separate it using tags, and
possibly go further and do separate RSS feeds for the different blog types. For now, I'm not worried
about that.

A little additional background: My wife [Krysta Curtis](http://ideatetowin.com) and I just started
a new independant game studio, [Plixl](http://plixl.com). We're working on our first game, a
hidden object game for Facebook and mobile. I'm sure I'll be talking about the particular game more
soon.

The technology stack for our game is pretty settled now. We're using Photoshop and Flash to create
the individual levels, using the open source library [Flump](https://github.com/threerings/flump)
to get the levels importable by a Starling/Stage3D runtime. Adobe AIR is used to build an iOS
package. Game UI is done in flump, and basic runloop management is handled with
[Flashbang-starling](https://github.com/tconkling/flashbang-starling). Game data is edited in
Google Drive spreadsheets, which are read and parsed into JSON. That JSON is stored in Amazon S3,
along with the Flump level output for fast client downloads. Finally, the little bit of user
account management that is needed is handled via a JSON REST service in Java Servlets.

I outlined those bits because the bulk of my blog posts for the next couple of months at least will
be directly related to something in that stack. We'll see where it goes from there!
