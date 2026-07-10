# Scambait Windows 10 Installer (Proxmox)

One-script bait VM setup. Clone this repo on the Windows 10 guest and run `Install-Scambait.ps1`.

## Repo layout

```text
Install-Scambait.ps1      # run this (as Admin) inside the VM
README.md
.gitignore
.gitattributes
host/
  proxmox-smbios.conf     # apply on the Proxmox HOST
assets/
  README.md
  camera/
    webcam_loop.mp4       # add your loop video (keep under ~50MB if possible)
  wallpapers/             # add .jpg / .png backgrounds
  personal-files/         # optional extras
  micerosoft/             # optional custom popup.html
  tools/                  # runtime downloads only (gitignored)
guide.html                # XAMPP/DSJAS tutorial reference (optional)
```

## What to add before you push

1. Drop wallpapers into `assets/wallpapers/`
2. Drop `assets/camera/webcam_loop.mp4`
3. Edit persona/bank settings at the top of `Install-Scambait.ps1` if needed

## Push to GitHub

```powershell
cd "C:\Users\mccus\Desktop\scambait installer script"
git remote add origin https://github.com/YOU/scambait-installer.git
git branch -M main
git push -u origin main
```

## On the bait VM

```powershell
git clone https://github.com/YOU/scambait-installer.git
cd scambait-installer
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Install-Scambait.ps1
```

## Notes

- `modules/` and `config.ps1` are obsolete (ignored) — everything lives in `Install-Scambait.ps1`
- Videos over 100MB: use Git LFS or a GitHub Release, not a normal commit
- Proxmox SMBIOS masking is host-side; see `host/proxmox-smbios.conf`
