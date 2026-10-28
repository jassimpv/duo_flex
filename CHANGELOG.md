## 0.2.0

* Add Android support for device, app-window, display-region, and fold data.
* Read Android hinge angle from `Sensor.TYPE_HINGE_ANGLE` when available,
  reporting radians and filtering sensor noise while the event stream is active.
* Report Android `book` and `tabletop` postures from folding-feature orientation.
* Add `DuoFoldPosture.book` for vertical half-open fold configurations.
* Keep unavailable Android fold sensors and posture data nullable or unknown.

## 0.1.2

* Add the animated device dashboard to the pub.dev screenshots gallery.

## 0.1.1

* Show the device dashboard in the pub.dev screenshots gallery.

## 0.1.0

* Add typed APIs for iOS device, screen, display, and reserved-region data.
* Expose UIKit hinge angle and posture when the public APIs are available.
* Add screen and display event streams with lifecycle-aware observation.
* Add responsive layout, viewport, and posture-aware widgets.
* Preserve safe unavailable values on unsupported devices and OS versions.
