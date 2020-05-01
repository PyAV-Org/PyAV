---
name: Build bug report
about: Report on an issue while building or installing PyAV.
title: "FOO does not build."
labels: build
assignees: ''

---

**IMPORTANT:** Be sure to replace all template sections {{ like this }} or your issue may be discarded.


## Overview

{{ A clear and concise description of what the bug is. }}


## Expected behavior

{{ A clear and concise description of what you expected to happen. }}


## Actual behavior

{{ A clear and concise description of what actually happened. }}

Build report:
```
{{ Complete output of `python setup.py build`. Reports that do not show compiler commands will not be accepted (e.g. results from `pip install av`). }}
```


## Investigation

{{ What you did to isolate the problem. }}


## Reproduction

{{ Steps to reproduce the behavior. }}


## Versions

- OS: {{ e.g. macOS 10.13.6 }}
- PyAV runtime:
```
{{ Complete output of `python -m av --version` if you can run it. }}
```
- PyAV build:
```
{{ Complete output of `python setup.py config --verbose`. }}
```
- FFmpeg:
```
{{ Complete output of `ffmpeg -version` }}
```


## Research

I have done the following:

- [ ] Checked the [PyAV documentation](https://pyav.org/docs)
- [ ] Searched on [Google](https://www.google.com/search?q=pyav+how+do+I+foo)
- [ ] Searched on [Stack Overflow](https://stackoverflow.com/search?q=pyav)
- [ ] Looked through [old GitHub issues](https://github.com/PyAV-Org/PyAV/issues?&q=is%3Aissue)
- [ ] Asked on [PyAV Gitter](https://gitter.im/PyAV-Org)
- [ ] ... and waited 72 hours for a response.


## Additional context

{{ Add any other context about the problem here. }}
