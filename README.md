PsychoMonkey
============

PsychoMonkey is a framework for building monkey behavioral paradigms using Psychtoolbox. It includes the following features:

* Support for duplicating the main display to an auxiliary display or via the web, with fixation data overlaid
* EyeLink, analog, and simulated eye tracker support
* Modular, object-oriented design implemented as a thin layer on top of Psychtoolbox (<4 KLOC) with minimal new syntax


Usage Example
-------------

The distribution includes a sample paradigm for fixation training. Assuming you already have Psychtoolbox installed and configured, you can run it by adding the psychomonkey root directory and the PMServer directory to your path, editing ```example_five_dot_config.m```, and then running ```example_five_dot(example_five_dot_config)```. The functions and objects in the example paradigm beginning with ```PM``` are provided by the framework. The web server is presently hard-coded to run on port 28781.


To Do
-----

* Write documentation (if anyone actually wants to use this)
* Replace Java-WebSocket with Netty
* Increase the range of commands supported for web streaming
* Test PMEyeAnalog
* Optimize for speed