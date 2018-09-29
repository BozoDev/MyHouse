++++ Warning ++++

I had no documentation for any of the "commands" the script issues!!

++++ USE AT OWN RISK ++++

(I think my Archt's had the last available FW installed - newer than what the App suggests, so be warned again!)


My setup was not volume-control friendly:
TV -> HDMI-Matrix (ARC) -> Optical out -> Opt2Line conv. { -> interim "Line-In"-Volume-Adjust-Device via IR } -> Speakers "Line-In".
Only way was either the (iPhone on iTab or Android)-App or get up and press the Saturn-Ring a couple of times on both speakers. Including standing - head bowed - infront of TV and listening whether both speakers were (roughly) the same volume. 
The speakers expose at least 2 uPnP services that have Volume related settings, but alas - they don't seem to be able to change Line-In/Master volume through issueing uPnP requests.
Long story short - the speakers have an additional port open, that takes commands - I've found a few that work (for me & most of the time). It kinda goes round in silly circles, but the setup now is:
* defined 2 speakers in FHEM
* exported 1 to the Hue-proxy that picks them up & exports them
* Alexa finds the one "extended colour light 'main speakers'"

So now Alexa can interact with them (jupp & all via MQTT backend for communication ;) ). Commands like 'dim/brighten main spaekers' actually work (or 'set main speakers brightness to 66' ).
The script is pretty lousy though - no checks if online, sometimes the 'getVolume' returns no value, so I publish the volume at least one speaker returns. Works for me, since I also always set both speakers to same volume (which surprisingly works - haven't had 1 speaker set, but not the other yet). But since I don't think there'll be an "Archt Two" (or whatnot) - sodd it...
