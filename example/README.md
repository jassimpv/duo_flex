# DuoFlex example

This app demonstrates the `duo_flex` Flutter plugin.

- **Device** shows iOS device and display data, live safe-area measurements,
  native hinge angle and posture when UIKit supports them, capabilities, and
  stream events.
- **Adaptive UI** shows local viewport constraints, responsive layout
  breakpoints, and posture-aware content selection.

Native hinge values are not simulated. On unsupported devices or iOS versions,
the app shows unavailable values and uses the default responsive layout.
