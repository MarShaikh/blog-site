I write in Obsidian. I deploy with Quartz. The two directories are not the same directory, and I did not want to manually move files between them. I wanted a way in which I could do this, automatically ✨

Thing is Obsidian's vault live in one directory and the Quartz content directory in another. They have to be separate, because Quartz spits out `node_modules/`, `.quartz-cache/`, and `public/`, none of which I want Obsidian Sync trying to ingest. 

The first thing I tried was the obvious thing: symlink `blog-site/content` to the Posts folder. It mostly worked locally, but the deploy side made me nervous — git doesn't follow symlinks the way you want it to, and Cloudflare Pages was reading from the repo, not from my filesystem. I could have wrestled it into shape, but I wanted the repo to actually contain the content it was building. 

So I switched to a sync. The shape of the problem is small: when files in `Posts/` change, copy them into `content/`, commit, and push to git. Cloudflare Pages does the rest.

macOS already has a thing for this — `launchd` with `WatchPaths`. The plist sits at `~/Library/LaunchAgents/...` and watches the Posts directory:

```xml
<key>WatchPaths</key>
<array>
  <string>/Users/mrfshk/Documents/Everything/Blog stuff/Posts</string>
</array>
<key>ThrottleInterval</key>
<integer>30</integer>
```

The 30-second throttle is there because Obsidian writes can come in bursts when I save or autosync, and I don't want a fresh run every keystroke.

One small wrinkle: launchd wants to invoke a thing, and the thing it invokes plays better as an app than a raw shell script when permissions get involved. So the plist points at an AppleScript applet whose entire body is:

```applescript
do shell script "/Users/mrfshk/Documents/blog-site/scripts/sync-posts.sh"
```

The applet is a thin shim. The actual work is in the shell script:

```bash
SRC="/Users/mrfshk/Documents/Everything/Blog stuff/Posts/"
DST="/Users/mrfshk/Documents/blog-site/content/"
LOCK="/tmp/blog-sync.lock"

if ! mkdir "$LOCK" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK"' EXIT

rsync -a --delete \
  --exclude '.DS_Store' --exclude '.obsidian' --exclude '.trash' \
  "$SRC" "$DST"

if [[ -n "$(git status --porcelain content/)" ]]; then
  git add content/
  git commit -m "Sync posts from Obsidian vault"
  git push origin main
fi
```

A few details worth calling out. The `mkdir` lock is the cheapest cross-process mutex on Unix — `mkdir` is atomic, so if two launchd invocations race, only one wins. The excludes keep Obsidian's metadata folders out of the published site. The git block only fires when there's an actual diff, so a sync that produces no changes doesn't generate noise commits.

The flag that matters most is `--delete`. It makes `Posts/` the single source of truth — anything that exists in `content/` but not in `Posts/` gets wiped on the next run. 

This bit me once. The Quartz `index.md` was sitting in `content/` only, because that's where the scaffold dropped it. The first sync after I set this up would have deleted it. So I moved it into `Posts/` alongside the rest of the writing, which is where it should have been anyway. The homepage is a post too.

Logs go to `/tmp/blog-sync.log`. When something looks off, that's the first place I check.

The whole thing is maybe forty lines of config and shell, and I haven't thought about it since.
