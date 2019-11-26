---
name: FFmpeg feature request
about: Request a feature of FFmpeg be exposed or supported by PyAV.
title: "Allow FOO to BAR"
labels: enhancement
assignees: ''

---

**IMPORTANT:** Be sure to replace all template sections {{ like this }} or your issue may be discarded.


## Overview

{{ A clear and concise description of what the feature is. }}


## Existing FFmpeg API

{{ Link to appropriate FFmpeg documentation, ideally the API doxygen files at https://ffmpeg.org/doxygen/trunk/ }}


## Expected PyAV API

{{ A description of how you think PyAV should behave. }}

Example:
```
{{ An example of how you think PyAV should behave. }}
```


## Investigation

{{ What you did to isolate the problem. }}


## Reproduction

{{ Steps to reproduce the behavior. If the problem is media specific, include a link to it. Only send media that you have the rights to. }}


## Versions

- OS: {{ e.g. macOS 10.13.6 }}
- PyAV runtime:
```
{{ Complete output of `python -m av --version`. If this command won't run, you are likely dealing with the build issue and should use the appropriate template. }}
```
- PyAV build:
```
{{ Complete output of `python setup.py config --verbose`. }}
```
- FFmpeg:
```
{{ Complete output of `ffmpeg -version` }}
```


## Additional context

{{ Add any other context about the problem here. }}
