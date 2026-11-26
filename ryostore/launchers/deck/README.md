# Deck

A terminal-pane launcher for Super+Space, in the same language as the Deck
notification card and the Command Deck.

- a dark-blue `launch` pill names the pane
- you type after a `λ`, with an fzf-style `matches/total` count at the end of the line
- results are rows; the selected one becomes a dark-blue pill
- every colour is a Material role from the live palette, so it follows the wallpaper

## Keys

| Key | Action |
|---|---|
| type | filter by name, then generic name, keywords and description |
| `↓` `↑`, `Ctrl+J` `Ctrl+K`, `Ctrl+N` `Ctrl+P`, `Tab` | move |
| `Enter` or click | open |
| `Alt+1` … `Alt+9` | open the Nth visible row |
| `Ctrl+U` | clear the query |
| `Esc` or click outside | close |

Pinned apps (Settings → App Launcher → Favorites) come first and carry a `•`;
apps you opened this session rise next. Hidden apps never show.
