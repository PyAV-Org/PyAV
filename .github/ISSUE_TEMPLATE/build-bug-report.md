---
name: Build bug report
about: Report on an issue while building PyAV.
title: "[BUILD] The foo does not build."
labels: build
assignees: ''

---

This is a bug encountered while building or installing PyAV. If you can import and use PyAV, it is considered a runtime issue and you must use the appropriate template.

**IMPORTANT:** Be sure to fill in all applicable sections {{ in braces }} or your issue may be discarded.

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

## Additional context
{{ Add any other context about the problem here. }}
