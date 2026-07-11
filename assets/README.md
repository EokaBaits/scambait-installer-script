# Media assets for the scambait installer

Put files here, commit them with the repo, then on the VM:

```text
git clone https://github.com/YOU/scambait-installer.git
cd scambait-installer
.\Install-Scambait.ps1
```

## Layout

```text
assets/
  camera/
    webcam_loop.mp4      # looped elderly webcam face; hidden feeder (no OBS), keep under ~50MB
  wallpapers/
    *.jpg / *.png        # right-click Set as desktop background targets
  personal-files/        # optional extras copied into Documents
  micerosoft/            # optional custom popup.html
```

## GitHub size tips

| Type | Guidance |
|------|----------|
| Wallpapers | Fine in normal git (a few MB each) |
| Webcam video | Prefer under 50MB. Over 100MB GitHub rejects. Use [Git LFS](https://git-lfs.com/) or attach `webcam_loop.mp4` to a GitHub **Release** and put that URL in the script config |
| Private repo | `git clone` with auth works; raw downloads need a token |

If you only copy `Install-Scambait.ps1` (no clone), set `Assets.GitHubOwner` / `GitHubRepo` / `Files` at the top of the script so it pulls these paths from `raw.githubusercontent.com`.
