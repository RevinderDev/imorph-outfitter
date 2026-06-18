# iMorph Outfits

> [!WARNING]  
> This has been purely vibecoded for fun. No code has been reviewed, though the manual testing was conducted.


<p align="center">
  <img src=".github/main.png" alt="Main Image" width="100%">
</p>

An elegant, grid-based wardrobe launcher and manager designed for tracking and executing iMorph profiles efficiently.

---

## Features

* **Adaptive Grid Layouts:** Toggle seamlessly between layout scales: `1xN (Small)`, `2xN (Medium)`, `3xN (Large)`, or `4xN (Extra Alex)`.
* **Instant Filtering:** Real-time search instantly narrows down your outfit choices with every typed character.
* **Smart Favorites:** Pin frequently used morphs to generate a persistent index shortcut path for chat commands.
* **Decoupled Editor Modals:** Keeps launcher visuals clean by offloading editing fields into a right-click pop-up dialog.

---

## Slash Commands

Access runtime tools directly using either **`/rev`** or **`/imo`**:

| Command | Description |
| --- | --- |
| `/rev` | Toggles the main wardrobe grid panel. |
| `/rev help` | Outputs the diagnostic command listing to the chat frame. |
| `/rev random` | Selects and executes one profile entirely at random. |
| `/rev favourite list` | Prints a numbered breakdown of all pinned favorite items. |
| `/rev favourite random` | Selects and executes a random profile strictly from your favorites. |
| `/rev favourite <number>` | Instantly fires the outfit associated with that favorite number block. |

---

## Usage Shortcuts

> **Left-Click Button:** Instantly route morph commands directly to the chat client engine.

> **Right-Click Button:** Open the pop-up configuration matrix modal to update labels, commands, or add text notes.

> **Star Button:** Toggle favorite pinning flags on the fly. Unstarred icons stay dim to keep your UI visually quiet.
