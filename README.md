# Highlighter

Speedwalk path highlighter for Mudlet

## Description

This package allows you to highlight your speedwalk paths in a different colour
so that you can more easily see where you are going.

## Configuration

In Mudlet, type `highlight` to see the help information for this package.

* `highlight set` - See your current preference settings
* `highlight set <preference>` - See the current value of a preference
* `highlight set <preference> <value>` - Set a preference to a value

  Available preferences:
  * `fade` - Enable or disable the fade effect (`on` or `off`, default: off)
  * `rollout` - Enable or disable the rollout effect (`on` or `off`, default: on)
  * `step` - Set the granularity of the fade (default: 10)
  * `delay` - Set the speed of the fade (default: 0.025)
  * `colour` - Set the colour of the highlight (`auto` or a named colour, default: auto)
  * `alpha` - Set the opacity of the highlight (0-255, default: 255)

Note that the colour must be a valid [Mudlet colour name](https://wiki.mudlet.org/images/c/c3/ShowColors.png).

## Events

This package listens to the following events in order to function. You will
need to ensure that these events are passed along with the required arguments
(if any).

### `onMoveMap`

Trigger this event when the player has moved to a new room. Highlighter uses
this information to know when to begin fading the previous room. Triggering it
again for the room the player is already in does nothing.

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

### `onSpeedwalkReset`

Trigger this event when the speedwalk has been reset. Highlighter will use this
notification to immediately remove all highlights.

#### Arguments

* `none` - No arguments are required. Mappers may send `exception` and `reason`,
  but neither changes what Highlighter does.

## Dependencies

The following packages are required and will be automatically installed if they
are missing:

* [Helper](https://github.com/gesslar/Helper)

## License

`highlighter` is released under the [0BSD](LICENSE.txt).
