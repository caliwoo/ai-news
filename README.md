# AI NEWS · Daily Digest

Public archive of Cali’s weekday morning AI newsletter digest.

- **Live site:** https://caliwoo.github.io/ai-news/
- Each edition lives at `https://caliwoo.github.io/ai-news/YYYY-MM-DD/`
- The home page shows the newest edition. The menu lists every day, newest first.
- When an audio summary exists, the page includes a play button that points at that day’s MP3, usually `https://caliwoo.github.io/cali-audio/ai-news/ai-news-YYYY-MM-DD.mp3`.

This is a Hugo site. Source is on `main`. The built site is published to the `gh-pages` branch, which GitHub Pages serves.

## Add a day

Write the digest body as Markdown or HTML (subject headings, stories, sources). Then, from this directory:

```bash
./publish.sh YYYY-MM-DD path/to/body.md
```

To attach audio, pass the MP3 URL, or `auto` for the conventional path above:

```bash
./publish.sh 2026-11-17 body.md auto
./publish.sh 2026-11-17 body.md https://caliwoo.github.io/cali-audio/ai-news/ai-news-2026-11-17.mp3
```

`publish.sh` will:

1. Write `content/digest/YYYY-MM-DD.md` (title is taken from the first Markdown `#` heading, or “Daily digest”)
2. Build the site with Hugo
3. Commit the source on `main` and the built files on `gh-pages`
4. Push both branches
5. Wait until the live edition URL returns HTTP 200

Hugo is required (`hugo_extended`). If it is missing, the script tries to install v0.170.0.

## Preview locally

```bash
hugo server -D
```

The first published page is the 14 November 2026 launch edition. It lists the subscribed sources and does not invent news; regular digests begin with the next issues that arrive.

Subscribed sources: The Deep View, The Rundown AI, AI for Work, Lenny's Newsletter, Superhuman AI, Superhuman Product Management, and The Code Cybersecurity.
