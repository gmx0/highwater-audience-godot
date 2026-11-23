# Highwater Audience

A short, original 2D command game about a flood in Reed County. Hear captains'
petitions, authorize their plans, and follow their squads on a storm chart.
Hold North Gate and open the ferry before their deadlines. An independent rider
can warn Willow Hamlet without taking either squad off its route.

## Play

Open `project.godot` in Godot 4.6.3 (Compatibility renderer) and press F6 from
the main scene or F5 from any editor tab. There are no dependencies or add-ons
for the editor. To export, install the matching official release templates.
For the Web export, extract the archive, serve that directory over local HTTP
(e.g. `python -m http.server 8000 --bind 127.0.0.1`), and open
`http://127.0.0.1:8000/` in a desktop browser. Do not open the HTML as a file.

| Key | Order |
| --- | --- |
| **1** | Authorize Captain Fen to shore up North Gate |
| **2** | Authorize Captain Sable to secure the Ferry Crossing (from watch 01) |
| **C** | Send Iona alone to warn Willow Hamlet (optional, from watch 01) |
| **Space** | Run or pause the clock |
| **R** | Restart the shift |

All controls also have buttons. The game starts paused. You can issue orders
while paused; time, arrivals, and movement are frozen until you run the clock.
Dispatch and arrival estimates are expressed in whole watch marks, with seven
seconds between them. Arrival on the deadline mark counts. North Gate is due
at 04 and the ferry is due at 06. Try dispatching North at 00 and the ferry
as soon as the second petition appears at 01. The shift ends at 06 unless
you miss a required deadline earlier.

## Provenance

Fresh game code, interface, map geometry and text. No imported art, audio or
other project files. The Godot engine/runtime and its bundled components are
covered by `GODOT_NOTICES.txt`, included with the download bundles.
