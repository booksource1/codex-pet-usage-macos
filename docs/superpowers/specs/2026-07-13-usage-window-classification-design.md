# Usage Window Classification Fix — Design

## Problem

The ChatGPT usage endpoint no longer guarantees that `primary_window` means the
five-hour window and `secondary_window` means the seven-day window. The current
live response places a 604800-second (seven-day) bucket in `primary_window` and
omits `secondary_window`. The app therefore labels the seven-day remaining value
as five-hour usage and renders the missing bucket as `0%`.

## Required behavior

The app identifies supported buckets by their declared window duration instead
of their `primary` or `secondary` position:

- `18000` seconds is the five-hour window.
- `604800` seconds is the seven-day window.
- When at least one bucket declares a duration, only buckets with one of these
  recognized durations are assigned to the two displayed windows. A missing or
  unrecognized bucket is not inferred from its position.
- For legacy payloads in which neither bucket declares a duration, retain the
  reference-compatible positional fallback: primary is five-hour and secondary
  is seven-day.

Classification happens in the decoder so the existing snapshot fields keep
their semantic meaning: `primary*` represents five-hour data and `secondary*`
represents seven-day data throughout presentation, rings, and logging.

## Missing-window presentation

An available response may contain only one supported window. Each missing
window is rendered independently:

- `5小时 剩余 -- · --后刷新`
- `7天 剩余 -- · --后刷新`

A present percentage still renders normally. If only its reset time is absent,
the countdown alone is `--`. A missing percentage draws no ring arc. Operational
logs use `5h=--` or `7d=--` instead of converting missing values to zero.

If neither supported window has a percentage, preserve the existing fully
unavailable presentation and fallback behavior.

## Scope

This change only corrects window classification and missing-value presentation.
It does not change the endpoint, polling intervals, authentication, hover
behavior, layout, colors, startup behavior, or persisted data.

## Verification

Tests must first reproduce the real response shape: a primary bucket with
`used_percent = 23` and `limit_window_seconds = 604800`, with no secondary
bucket. They must prove that the decoded result is five-hour missing and
seven-day remaining `77%`, and that presentation/log formatting emits `--` for
the missing five-hour window.

Existing tests must continue to prove:

- the conventional 18000-second primary and 604800-second secondary mapping;
- positional fallback when both duration fields are absent;
- `remaining_percent` and `used_percent` conversion;
- complete-unavailability behavior;
- all unrelated overlay and command behavior.
