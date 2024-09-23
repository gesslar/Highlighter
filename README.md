# Highlighter

Speedwalk path highlighter for Mudlet

## Description

This package allows you to highlight your speedwalk paths in a different colour
so that you can more easily see where you are going.

## Configuration

In Mudlet, type `highlight` to see the help information for this package.

* `highlight set` - See your current preference settings
* `highlight set <preference> <value>` - Set a preference to a value

  Available preferences:
  * `step` - Set the granularity of the fade (default: 0.0)
  * `delay` - Set the speed of the fade (default: 0.0)
  * `colour` - Set the colour of the highlight (default: gold)

Note that the colour must be a valid Mudlet colour name.

## Events

This package listens to the following events in order to function. You will
need to ensure that these events are passed along with the required arguments
(if any).

### `onMoveMap`

Trigger this event when the player has moved to a new room. Highlighter uses
this information to know when to begin fading the previous room.

#### Arguments

* `current room id` - The id of the room the player has arrived in.

### `sysSpeedwalkStarted`

Trigger this event to indicate that the speedwalk has started. Highlighter will
use this notification and information provided to highlight the route.

#### Arguments

* `none` - No arguments are required.

### `sysSpeedwalkFinished`

Trigger this event when the speedwalk has finished. Highlighter will use this
notification to know when to fade all of the remaining highlights.

#### Arguments

* `none` - No arguments are required.

None

### `onSpeedwalkReset`

Trigger this event when the speedwalk has been reset. Highlighter will use this
notification immediately remove all highlights.

#### Arguments

* `exception` - True or false if the reset was due to an exception.
* `reason` - The reason the speedwalk was reset.

## Credits

[Marker icons created by mavadee - Flaticon](https://www.flaticon.com/free-icons/marker)
