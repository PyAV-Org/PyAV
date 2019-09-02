---
name: Runtime bug report
about: Report on an issue while running PyAV.
title: "[BUG] The foo does not bar."
labels: bug
assignees: ''

---

This is a bug encountered while using PyAV. If you cannot build or import PyAV, it is considered a build issue and you must use the appropriate template.

**IMPORTANT:** Be sure to fill in all applicable sections {{ in braces }} or your issue may be discarded.

## Overview
{{ A clear and concise description of what the bug is. }}

## Expected behavior
{{ A clear and concise description of what you expected to happen. }}

## Actual behavior
{{ A clear and concise description of what actually happened. }}

```
{{ Include complete tracebacks if there are any exceptions. }}
```

## Investigation
{{ What you did to isolate the problem. }}

## Reproduction
{{ Steps to reproduce the behavior. If the problem is media specific, include a link to it. Only send media that you have the rights to. }}

## Versions
- OS: {{ e.g. macOS 10.13.6 }}
- PyAV:
```
{{ Complete output of `python -m av --version`. }}
```
- FFmpeg:
```
{{ Complete output of `ffmpeg -version` }}
```

## Additional context
{{ Add any other context about the problem here. }}
